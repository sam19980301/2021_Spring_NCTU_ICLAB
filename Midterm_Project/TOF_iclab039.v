//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Si2 LAB @NYCU ED430
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2022 SPRING
//   Midterm Proejct            : TOF  
//   Author                     : Wen-Yue, Lin
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : TOF.v
//   Module Name : TOF
//   Release version : V1.0 (Release Date: 2022-3)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module TOF(
    // CHIP IO
    clk,
    rst_n,
    in_valid,
    start,
    stop,
    window,
    mode,
    frame_id,
    busy,

    // AXI4 IO
    arid_m_inf,
    araddr_m_inf,
    arlen_m_inf,
    arsize_m_inf,
    arburst_m_inf,
    arvalid_m_inf,
    arready_m_inf,
    
    rid_m_inf,
    rdata_m_inf,
    rresp_m_inf,
    rlast_m_inf,
    rvalid_m_inf,
    rready_m_inf,

    awid_m_inf,
    awaddr_m_inf,
    awsize_m_inf,
    awburst_m_inf,
    awlen_m_inf,
    awvalid_m_inf,
    awready_m_inf,

    wdata_m_inf,
    wlast_m_inf,
    wvalid_m_inf,
    wready_m_inf,
    
    bid_m_inf,
    bresp_m_inf,
    bvalid_m_inf,
    bready_m_inf 
);
// ===============================================================
//                      Parameter Declaration 
// ===============================================================
parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32;    // DO NOT modify AXI4 Parameter
parameter SRAM_DATA_WIDTH = 128, SRAM_ADDR_WIDTH = 4;

parameter STATE_IDLE =          3'd0;
parameter STATE_INPUT_WAIT =    3'd1; // gap between start signals
parameter STATE_INPUT_SIG =     3'd2; // processing input start signals
parameter STATE_INPUT_DRAM =    3'd3; // processing input DRAM signals
parameter STATE_CALC =          3'd4; // calculate distance
parameter STATE_LOAD =          3'd5; // preparing output
parameter STATE_OUTPUT_DRAM =   3'd6; // store data to DRAM

parameter AXI_IDLE =   3'd0;
parameter AXI_W_ADDR = 3'd1;
parameter AXI_W_DATA = 3'd2;
parameter AXI_W_RESP = 3'd3;
parameter AXI_R_ADDR = 3'd4;
parameter AXI_R_DATA = 3'd5;

integer i, j;
genvar idx;


// ===============================================================
//                      Input / Output 
// ===============================================================

// << CHIP io port with system >>
input           clk, rst_n;
input           in_valid;
input           start;
input [15:0]    stop;     
input [1:0]     window; 
input           mode;
input [4:0]     frame_id;
output reg      busy;       

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
    Your AXI-4 interface could be designed as a bridge in submodule,
    therefore I declared output of AXI as wire.  
    Ex: AXI_interface AXI_INF(...);
*/

// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)    axi read address channel 
output wire [ID_WIDTH-1:0]      arid_m_inf;
output wire [1:0]            arburst_m_inf;
output wire [2:0]             arsize_m_inf;
output wire [7:0]              arlen_m_inf;
output wire                  arvalid_m_inf;
input  wire                  arready_m_inf;
output wire [ADDR_WIDTH-1:0]  araddr_m_inf;
// ------------------------
// (2)    axi read data channel 
input  wire [ID_WIDTH-1:0]       rid_m_inf;
input  wire                   rvalid_m_inf;
output wire                   rready_m_inf;
input  wire [DATA_WIDTH-1:0]   rdata_m_inf;
input  wire                    rlast_m_inf;
input  wire [1:0]              rresp_m_inf;
// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1)     axi write address channel 
output wire [ID_WIDTH-1:0]      awid_m_inf;
output wire [1:0]            awburst_m_inf;
output wire [2:0]             awsize_m_inf;
output wire [7:0]              awlen_m_inf;
output wire                  awvalid_m_inf;
input  wire                  awready_m_inf;
output wire [ADDR_WIDTH-1:0]  awaddr_m_inf;
// -------------------------
// (2)    axi write data channel 
output wire                   wvalid_m_inf;
input  wire                   wready_m_inf;
output wire [DATA_WIDTH-1:0]   wdata_m_inf;
output wire                    wlast_m_inf;
// -------------------------
// (3)    axi write response channel 
input  wire  [ID_WIDTH-1:0]      bid_m_inf;
input  wire                   bvalid_m_inf;
output wire                   bready_m_inf;
input  wire  [1:0]             bresp_m_inf;
// -----------------------------

// ===============================================================
//                      Wire & Register
// ===============================================================
// FSM
reg [2:0] current_state, next_state;
reg [2:0] current_axi_state, next_axi_state;
reg [7:0] cnt;
reg [8:0] subcnt;

wire flag_finish_calc;
wire flag_finish_w_DRAM;
wire flag_finish_load;

// metadata information
reg [1:0]   window_val;
reg         mode_val;
reg [4:0]   frame_id_val;

// SRAM Configurations
//    No. of words:  16
//    No. of  bits: 128
//        Mux type:   4
// Frequency (MHz): 100

// Memory signals
// SRAM signals
wire [SRAM_DATA_WIDTH-1:0]  mem_q[15:0];
reg                         mem_wen[15:0];
reg  [SRAM_ADDR_WIDTH-1:0]  mem_addr;
reg  [SRAM_DATA_WIDTH-1:0]  mem_data[15:0];

// DRAM additional signals
reg [ADDR_WIDTH-1:0] awaddr_m_inf_reg;
reg [ADDR_WIDTH-1:0] araddr_m_inf_reg;
reg [DATA_WIDTH-1:0] wdata_m_inf_reg_arr[1:0];

// buffer signals
reg [7:0]   cnt_buffer_arr[1:0];
// the Slave (input) signals from AXI4 should not be pipelined. Use it directly otherwise there may be hold time violation 

// calculation of distance
// reg [10:0] bin_arr[15:0][8:0]; // bin_arr[# histogram][max window range + 1]
reg [10:0] max_bin[15:0];
reg [ 7:0] distance[15:0], bin[15:0];
reg [ 3:0] start_cycle, start_ind;


// ===============================================================
//                          Design
// ===============================================================
// state FSM
// current state
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) current_state <= STATE_IDLE;
    else current_state <= next_state;
end

// next state
always @(*) begin
    if (!rst_n)                             next_state = STATE_IDLE;
    else begin
        case (current_state)
            STATE_IDLE: begin
                if (in_valid && mode)       next_state = STATE_INPUT_DRAM;  // mode 1: read histogram from DRAM
                else if (in_valid && ~mode) next_state = STATE_INPUT_WAIT;  // mode 0: read histogram from port
                else                        next_state = current_state;                
            end
            STATE_INPUT_WAIT: begin
                if (start)                  next_state = STATE_INPUT_SIG;
                else                        next_state = current_state;
            end
            STATE_INPUT_SIG: begin
                if (!in_valid)              next_state = STATE_CALC;
                else if (!start)            next_state = STATE_INPUT_WAIT;
                else                        next_state = current_state;
            end
            STATE_INPUT_DRAM: begin
                if (rlast_m_inf)            next_state = STATE_CALC;
                else                        next_state = current_state;
            end
            STATE_CALC: begin
                if (flag_finish_calc)       next_state = STATE_LOAD;
                else                        next_state = current_state;
            end
            STATE_LOAD: begin
                if (flag_finish_load)       next_state = STATE_OUTPUT_DRAM;
                else                        next_state = current_state; 
            end
            STATE_OUTPUT_DRAM: begin
                if (flag_finish_w_DRAM)     next_state = STATE_IDLE;
                else                        next_state = current_state;
            end
            default:                        next_state = current_state;
        endcase
    end
end

assign flag_finish_calc =   (subcnt==258);
assign flag_finish_load =   (cnt_buffer_arr[1]==15);
assign flag_finish_w_DRAM = (bvalid_m_inf) && (cnt==0);

// output logic
// According to SPEC, an extra cycle of low-signal busy is allowed after in_valid pulls low
// The implementation here is more strict
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                                 busy <= 0;
    else if (
        ((current_state==STATE_INPUT_SIG) && (!in_valid)) ||
        ((current_state==STATE_INPUT_DRAM))
    )                                                           busy <= 1;
    else if (flag_finish_w_DRAM)                                busy <= 0;
    else                                                        busy <= busy;
end

// counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                 cnt <= 0;
    else begin
        case (current_state)
            STATE_IDLE:                         cnt <= 0;
            STATE_INPUT_WAIT:                   cnt <= cnt + start;
            STATE_INPUT_SIG: begin              // counter of bin signals
                if ((!in_valid) || (!start))    cnt <= 0;
                else                            cnt <= cnt + 1;
            end
            STATE_INPUT_DRAM: begin             // counter of bin signals
                if (rvalid_m_inf)               cnt <= cnt + 1;
                else                            cnt <= cnt;  
            end
            STATE_CALC:                         cnt <= cnt;
            STATE_LOAD: begin                   // counter of cycles
                if (flag_finish_load)           cnt <= 0;
                else                            cnt <= cnt + 1;
            end
            STATE_OUTPUT_DRAM: begin            // counter of burst
                if (wready_m_inf)               cnt <= cnt + 1;
                else                            cnt <= cnt;
            end
            default:                            cnt <= cnt;
        endcase
    end
end

// sub-counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                         subcnt <= 0;
    else begin
        case (current_state)
            STATE_IDLE:                 subcnt <= 0;
            STATE_INPUT_SIG: begin  // first burst or not, used for bin counting
                if (!in_valid)          subcnt <= 0;
                else if (!start)        subcnt <= 1;
                else                    subcnt <= subcnt;
            end
            STATE_CALC: begin       // counter of cycles
                if (flag_finish_calc)   subcnt <= 0;
                else                    subcnt <= subcnt + 1;
            end
            default:                    subcnt <= subcnt;
        endcase
    end
end

// axi4 state FSM
// current axi4 state 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_axi_state <= AXI_IDLE;
    else        current_axi_state <= next_axi_state;
end

// next axi4 state
always @(*) begin
    if (!rst_n)                         next_axi_state = AXI_IDLE;
    else begin
        case (current_axi_state)
            AXI_IDLE: begin
                case (current_state)
                    STATE_INPUT_DRAM:   next_axi_state = AXI_R_ADDR;
                    STATE_OUTPUT_DRAM:  next_axi_state = AXI_W_ADDR;
                    default:            next_axi_state = current_axi_state;
                endcase
            end
            AXI_W_ADDR: begin
                if (awready_m_inf)      next_axi_state = AXI_W_DATA;
                else                    next_axi_state = current_axi_state;
            end
            AXI_W_DATA: begin
                if (wlast_m_inf)        next_axi_state = AXI_W_RESP;
                else                    next_axi_state = current_axi_state;
            end
            AXI_W_RESP: begin
                if (bvalid_m_inf)       next_axi_state = AXI_IDLE;
                else                    next_axi_state = current_axi_state;
            end
            AXI_R_ADDR: begin
                if (arready_m_inf)      next_axi_state = AXI_R_DATA;
                else                    next_axi_state = current_axi_state;
            end
            AXI_R_DATA: begin
                if (rlast_m_inf)        next_axi_state = AXI_IDLE;
                else                    next_axi_state = current_axi_state;
            end
            default:                    next_axi_state = current_axi_state;
        endcase
    end
end

// metadata signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        window_val      <= 0;
        mode_val        <= 0;
        frame_id_val    <= 0;
    end
    else if ((current_state==STATE_IDLE) && (in_valid)) begin
        window_val      <= window;
        mode_val        <= mode;
        frame_id_val    <= frame_id;
    end
    else begin
        window_val      <= window_val;
        mode_val        <= mode_val;
        frame_id_val    <= frame_id_val;
    end
end

// Memory modules
generate
    for (idx=0; idx<16; idx=idx+1) begin: SRAM_loop
        MEM_100MHz U1(
            .Q(mem_q[idx]),
            .CLK(clk),
            .CEN(1'b0),
            .WEN(mem_wen[idx]),
            .A(mem_addr),
            .D(mem_data[idx]),
            .OEN(1'b0)
        );
    end
endgenerate

// SRAM signals

// Count    Operation
//   0      Get  1st input
//   1      Get  2nd input
//   2      Get  3rd input
//   3      Get  4th input
//   4      Get  5th input
//   5      Get  6th input
//   6      Get  7th input
//   7      Get  8th input
//   8      Get  9th input
//   9      Get 10th input
//  10      Get 11th input
//  11      Get 12th input
//  12      Get 13th input
//  13      Get 14th input
//  14      Get 15th input, set  read signal
//  15      Get 16th input, set write signal
//  16      Get 17th input, write back 1st burst, read in 2nd burst
//  17      Get 18th input
//  18      Get 19th input
// ...      ...

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                         for (i=0;i<16;i=i+1) mem_wen[i] <= 1;
    else begin
        case (current_state)
            STATE_INPUT_SIG: begin
                if (cnt[3:0]==4'd15)    for (i=0;i<16;i=i+1) mem_wen[i] <= 0;
                else                    for (i=0;i<16;i=i+1) mem_wen[i] <= 1;
            end
            STATE_INPUT_DRAM:           for (i=0;i<16;i=i+1) if ((rvalid_m_inf) && (cnt[7:4]==i)) mem_wen[i] <= 0; else mem_wen[i] <= 1;
            STATE_CALC: begin
                if (subcnt==258)        for (i=0;i<16;i=i+1) mem_wen[i] <= 0;
                else                    for (i=0;i<16;i=i+1) mem_wen[i] <= 1;
            end
            default:                    for (i=0;i<16;i=i+1) mem_wen[i] <= 1;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                         mem_addr <= 0;
    else begin
        case (current_state)
            STATE_IDLE:                 mem_addr <= 0;
            STATE_INPUT_WAIT:           mem_addr <= 0;
            STATE_INPUT_SIG: begin
                if (cnt[3:0]==4'd15)    mem_addr <= cnt[7:4];       // write back
                else                    mem_addr <= cnt[7:4] + 1;   //  read next
            end
            STATE_INPUT_DRAM:           mem_addr <= cnt[3:0];
            STATE_CALC:                 mem_addr <= (subcnt<256) ? subcnt[7:4] : 15;
            STATE_LOAD:                 mem_addr <= cnt[3:0]; 
            STATE_OUTPUT_DRAM:          mem_addr <= cnt[3:0];
            default:                    mem_addr <= mem_addr;
        endcase
    end 
end

// Specify the signals using multiple always blocks rather than a single large blcok with for loop inside to avoid Synthesis error (maybe because OOM or high fanout)
generate
    for (idx=0;idx<16;idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)                         mem_data[idx] <= 0;
            else begin
                case (current_state)
                    STATE_INPUT_WAIT,
                    STATE_INPUT_SIG: begin  // bin counting
                        if (cnt[3:0]==0)        mem_data[idx] <= (subcnt==0) ? {127'b0, stop[idx]} : {mem_q[idx][127:  8], mem_q[idx][  7:  0] + stop[idx]};
                        else begin
                                                mem_data[idx][  7:  0] <= mem_data[idx][  7:  0];
                                                mem_data[idx][119:  8] <= mem_data[idx][127: 16];
                                                mem_data[idx][127:120] <= mem_data[idx][ 15:  8] + stop[idx];
                        end
                    end
                    STATE_INPUT_DRAM:           mem_data[idx] <= rdata_m_inf;                                   // get from DRAM read signals

                    // resource sharing for calculate distance
                    STATE_CALC: begin
                        if (flag_finish_calc)   mem_data[idx] <= {distance[idx][7:0],mem_q[idx][119:0]};        // write back distance
                        else begin
                            case (subcnt)
                                0, 1, 258:      mem_data[idx] <= 0; 
                                default: begin
                                                // bin_arr[idx][0,1,2,3,4,5,6,7,8]
                                                mem_data[idx][(0+1)*11-1:0*11] <= mem_data[idx][(0+1)*11-1:0*11] + bin[idx] - ((subcnt<start_cycle) ? 0 : mem_data[idx][(1+1)*11-1:1*11]);
                                                mem_data[idx][(1+1)*11-1:1*11] <= (window_val==0) ? bin[idx] : mem_data[idx][(2+1)*11-1:2*11];
                                                mem_data[idx][(2+1)*11-1:2*11] <= (window_val==1) ? bin[idx] : mem_data[idx][(3+1)*11-1:3*11];
                                                mem_data[idx][(3+1)*11-1:3*11] <= mem_data[idx][(4+1)*11-1:4*11];
                                                mem_data[idx][(4+1)*11-1:4*11] <= (window_val==2) ? bin[idx] : mem_data[idx][(5+1)*11-1:5*11];
                                                mem_data[idx][(5+1)*11-1:5*11] <= mem_data[idx][(6+1)*11-1:6*11];
                                                mem_data[idx][(6+1)*11-1:6*11] <= mem_data[idx][(7+1)*11-1:7*11];
                                                mem_data[idx][(7+1)*11-1:7*11] <= mem_data[idx][(8+1)*11-1:8*11];
                                                mem_data[idx][(8+1)*11-1:8*11] <= bin[idx];
                                end
                            endcase
                        end
                    end

                    // resource sharing for writing back to DRAM
                    STATE_LOAD:             mem_data[idx] <= (cnt_buffer_arr[1]==idx) ? mem_q[0] : mem_data[idx];   // first burst data
                    STATE_OUTPUT_DRAM:      mem_data[idx] <= ((cnt_buffer_arr[1][3:0]==idx) && (wready_m_inf)) ?
                                                                mem_q[cnt_buffer_arr[1][7:4]+1] : mem_data[idx];    // update burst data
                    default:                mem_data[idx] <= mem_data[idx];
                endcase
            end
        end
    end
endgenerate

// AXI Signals
// AXI Read Signals
// AXI Read Address Channel
assign arid_m_inf =     4'b0;
assign arburst_m_inf =  2'b01;
assign arsize_m_inf =   3'b100;
assign arlen_m_inf =    8'd255;
assign arvalid_m_inf =  (current_axi_state==AXI_R_ADDR) ? 1 : 0;
assign araddr_m_inf =   araddr_m_inf_reg;

always @(*) begin
    araddr_m_inf_reg[31:20] = 12'h0;                            // constant 0
    araddr_m_inf_reg[19:16] = (frame_id_val[4]) ? 4'h2 : 4'h1;  // first / second half frame number
    araddr_m_inf_reg[15:12] = frame_id_val[3:0];                // remaining frame number
    araddr_m_inf_reg[11: 4] = cnt[7:0];                         // 16 burst & 16 histogram
    araddr_m_inf_reg[ 3: 0] = 4'h0;                             // constant 0
end

// AXI Read Data Channel
assign rready_m_inf = 1;

// AXI Write Signals
// AXI Write Address Channel
assign awid_m_inf =     4'b0;
assign awburst_m_inf =  2'b01;
assign awsize_m_inf =   3'b100;
assign awlen_m_inf =    8'd255; // 16 burst * 16 histogram
assign awvalid_m_inf =  (current_axi_state==AXI_W_ADDR) ? 1 : 0;
assign awaddr_m_inf =   awaddr_m_inf_reg;

always @(*) begin
    awaddr_m_inf_reg[31:20] = 12'h0;                            // constant 0
    awaddr_m_inf_reg[19:16] = (frame_id_val[4]) ? 4'h2 : 4'h1;  // first / second half frame number
    awaddr_m_inf_reg[15:12] = frame_id_val[3:0];                // remaining frame number
    awaddr_m_inf_reg[11: 8] = cnt[7:4];                         // current histogram
    awaddr_m_inf_reg[ 7: 4] = 4'h0;                             // write from head histogram
    awaddr_m_inf_reg[ 3: 0] = 4'h0;                             // constant 0
end

// AXI Write Data Channel
assign wvalid_m_inf =   1;
assign wdata_m_inf =    mem_data[cnt[3:0]];
assign wlast_m_inf =    ((current_axi_state==AXI_W_DATA) && (cnt==255)) ? 1 : 0;

// AXI Write Response Channel
assign bready_m_inf =   1;

// buffer signals
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) for (i=0;i<2;i=i+1) cnt_buffer_arr[i] <= 0;
    else begin
        cnt_buffer_arr[0] <= cnt;
        cnt_buffer_arr[1] <= cnt_buffer_arr[0];
    end
end

// calculation of distance
// reg [7:0] bin_arr[8:0]; // bin_arr[max window range + 1]
// bin_arr[0]   [1]     [2]     [3]     [4]     [5]     [6]     [7]     [8]

// Count    Operation           Window0     Window1     Window2     Window3     Currbin         Maxbin & Distance
//   0      Set read signal
//   1      
//   2      Get   1st input     +X          +X          +X          +X          Update currbin
//   3      Get   2rd input     +X-Y        +X          +X          +X          Update currbin  Update maxbin & dist      
//   4      Get   3nd input     +X-Y        +X-Z        +X          +X          Update currbin  Update maxbin & dist
//   5      Get   4th input                 +X-Z        +X          +X                          Update maxbin & dist          
//   6      Get   5th input                             +X-A        +X
//   7      Get   6th input                             +X-A        +X
//   8      Get   7th input                                         +X
//   9      Get   8th input                                         +X
//  10      Get   9th input                                         +X-B
//  11      Get  10th input                                         +X-B
//  12      Get  11th input
//  13      Get  12th input
//  14      Get  13th input
//  15      Get  14th input
//  16      Get  15th input
//  17      Get  16th input
//  18      Get  17th input     +X-Y        +X-Z        +X-A        +X-B        Update currbin  Update maxbin & dist
// ...      ...                 ...         ...         ...         ...         ...             ...
// 256      Get 255th input     +X-Y        +X-Z        +X-A        +X-B        Update currbin  Update maxbin & dist
// 257                                                                                          Update maxbin & dist
// 258                                                                                          Write distance   

always @(*) begin
    case (window_val)
        0:          start_cycle =  3;
        1:          start_cycle =  4;
        2:          start_cycle =  6;
        3:          start_cycle = 10;
        default:    start_cycle =  0; // will not happen
    endcase
end

always @(*) begin   // the index of bin starts from 1 --> offset should decrease by one
    case (window_val)
        0:          start_ind =  2;
        1:          start_ind =  3;
        2:          start_ind =  5;
        3:          start_ind =  9;
        default:    start_ind =  0; // will not happen
    endcase
end

// generate
//     for (idx=0;idx<16;idx=idx+1) begin
//         always @(posedge clk or negedge rst_n) begin
//             if (!rst_n)         for (i=0;i<9;i=i+1) bin_arr[idx][i] <= 0;
//             else begin
//                 case (subcnt)
//                     0, 1, 258:  for (i=0;i<9;i=i+1) bin_arr[idx][i] <= 0;
//                     default: begin
//                         bin_arr[idx][0] <= bin_arr[idx][0] + bin[idx] - ((subcnt<start_ind) ? 0 : bin_arr[idx][1]);
//                         bin_arr[idx][1] <= (window_val==0) ? bin[idx] : bin_arr[idx][2];
//                         bin_arr[idx][2] <= (window_val==1) ? bin[idx] : bin_arr[idx][3];
//                         bin_arr[idx][3] <= bin_arr[idx][4];
//                         bin_arr[idx][4] <= (window_val==2) ? bin[idx] : bin_arr[idx][5];
//                         bin_arr[idx][5] <= bin_arr[idx][6];
//                         bin_arr[idx][6] <= bin_arr[idx][7];
//                         bin_arr[idx][7] <= bin_arr[idx][8];
//                         bin_arr[idx][8] <= bin[idx];
//                     end
//                 endcase
//             end
//         end
//     end
// endgenerate

generate
    for (idx=0;idx<16;idx=idx+1) begin
        always @(*) begin
            case (subcnt[3:0])
                 2: bin[idx] = mem_q[idx][( 0+1)*8-1: 0*8];
                 3: bin[idx] = mem_q[idx][( 1+1)*8-1: 1*8];
                 4: bin[idx] = mem_q[idx][( 2+1)*8-1: 2*8];
                 5: bin[idx] = mem_q[idx][( 3+1)*8-1: 3*8];
                 6: bin[idx] = mem_q[idx][( 4+1)*8-1: 4*8];
                 7: bin[idx] = mem_q[idx][( 5+1)*8-1: 5*8];
                 8: bin[idx] = mem_q[idx][( 6+1)*8-1: 6*8];
                 9: bin[idx] = mem_q[idx][( 7+1)*8-1: 7*8];
                10: bin[idx] = mem_q[idx][( 8+1)*8-1: 8*8];
                11: bin[idx] = mem_q[idx][( 9+1)*8-1: 9*8];
                12: bin[idx] = mem_q[idx][(10+1)*8-1:10*8];
                13: bin[idx] = mem_q[idx][(11+1)*8-1:11*8];
                14: bin[idx] = mem_q[idx][(12+1)*8-1:12*8];
                15: bin[idx] = mem_q[idx][(13+1)*8-1:13*8];
                 0: bin[idx] = mem_q[idx][(14+1)*8-1:14*8];
                 1: bin[idx] = mem_q[idx][(15+1)*8-1:15*8];
                default: bin[idx] = 0; // will not happen
            endcase
        end
    end
endgenerate

generate
    for (idx=0;idx<16;idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                            max_bin[idx]    <= 0;
                            distance[idx]   <= 1;
            end
            else begin
                case (subcnt)
                    0, 1, 2, 258: begin
                            max_bin[idx]    <= 0;
                            distance[idx]   <= 1;
                    end
                    default: begin
                        if ((mem_data[idx][10:0] > max_bin[idx]) && (subcnt>=start_cycle)) begin // mem_data[x][10:0] === bin_arr[x][0]
                            max_bin[idx]    <= mem_data[idx][10:0];
                            distance[idx]   <= subcnt - start_ind;
                        end
                        else begin
                            max_bin[idx]    <= max_bin[idx];
                            distance[idx]   <= distance[idx];
                        end
                    end
                endcase
            end
        end
    end
endgenerate
endmodule
