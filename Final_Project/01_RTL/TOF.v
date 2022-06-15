//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Si2 LAB @NYCU ED430
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2022 SPRING
//   Final Proejct              : TOF  
//   Author                     : Wen-Yue, Lin
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : TOF.v
//   Module Name : TOF
//   Release version : V1.0 (Release Date: 2022-5)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
// `include "/usr/synthesis/dw/sim_ver/DW02_sum.v"

module TOF(
    // CHIP IO
    clk,
    rst_n,
    in_valid,
    start,
    stop,
    inputtype,
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

parameter SRAM_DATA_WIDTH = 'd64;   // (4 bit / entry) * (16 entry)
parameter SRAM_ADDR_WIDTH = 'd 4;   // log_2(256 / SRAM_DATA_WIDTH)
// Independent Spatial Coorelation          maximum value:  15
// Group Spatial Coorelation                maximum value:   4 
// Convex / Concave Spatial Correlation     maximum value:   7

parameter STATE_IDLE =          'd0;
parameter STATE_INPUT_WAIT =    'd1;    // gap between start signals
parameter STATE_INPUT_SIGNAL =  'd2;    // processing input start signals
parameter STATE_INPUT_DRAM =    'd3;    // processing input DRAM signals
parameter STATE_CALC =          'd4;    // calculating distance
parameter STATE_LOAD =          'd5;    // preparing output (first histogram)
parameter STATE_OUTPUT_DRAM =   'd6;    // storing data to DRAM

parameter CALC_IDLE =       'd0;
parameter CALC_RANDOM =     'd1;    // spatial coorelation Type 0
parameter CALC_GROUP =      'd2;    // spatial coorelation Type 1
parameter CALC_CONVEX =     'd3;    // spatial coorelation Type 2   & Type 3-1
parameter CALC_CONCAVE =    'd4;    // spatial coorelation Type 3-2

parameter AXI_IDLE =    'd0;
parameter AXI_W_ADDR =  'd1;
parameter AXI_W_DATA =  'd2;
parameter AXI_W_RESP =  'd3;
parameter AXI_R_ADDR =  'd4;
parameter AXI_R_DATA =  'd5;

integer i;
genvar  idx, idy;

// ===============================================================
//                      Input / Output 
// ===============================================================

// << CHIP io port with system >>
input           clk, rst_n;
input           in_valid;
input           start;
input [15:0]    stop;     
input [1:0]     inputtype; 
input [4:0]     frame_id;
output reg      busy;       

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
    Your AXI-4 interface could be designed as a bridge in submodule,
    therefore I declared output of AXI as wire.  
    Ex: AXI4_interface AXI4_INF(...);
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
reg     [2:0]   current_state,      next_state;
reg     [2:0]   current_axi_state,  next_axi_state;
reg     [2:0]   current_calc_state, next_calc_state;
reg     [7:0]   cnt;
wire    [7:0]   cnt_inc;    // cnt + 1
reg     [7:0]   cnt_buffer_arr      [24:0];
reg             in_calc_buffer_arr  [24:0]; 

wire    flag_finish_calc;
wire    flag_finish_load;
wire    flag_finish_w_DRAM;


// // metadata information
reg [1:0]   type_val;
reg [4:0]   frame_id_val;

// SRAM Configurations
//    No. of words:  16
//    No. of  bits:  64
//        Mux type:   4
// Frequency (MHz): 100

// Memory signals
// SRAM signals
wire [SRAM_DATA_WIDTH-1:0]  mem_q       [15:0];
reg                         mem_wen     [15:0];
reg  [SRAM_ADDR_WIDTH-1:0]  mem_addr;
reg  [SRAM_DATA_WIDTH-1:0]  mem_data    [15:0];
wire                        write_sram_cond;
wire                        first_bin_cond;
wire [3:0]                  bin_incr    [15:0];
reg                         bin_zero_init;

// DRAM additional signals
reg [ADDR_WIDTH-1:0]    a_rw_addr_m_inf_reg;
reg [DATA_WIDTH-1:0]    wdata_m_inf_reg;

// Distance Calculation
reg     [6:0]   bin_arr     [15:0][4:0];    // bin_arr[# histogram][pulse length]
// wire    [5:0]   a_mult_b    [15:0][4:1];
reg     [3:0]   bin         [15:0];
reg     [2:0]   weight_a    [ 4:1];
// Independent Spatial Coorelation          maximum value:  45  (15* 3)
// Group Spatial Coorelation                maximum value:  12  ( 4* 3)
// Convex / Concave Spatial Correlation     maximum value:  77  ( 7*11)
reg     [6:0]   bin_agg     [15:0][14:0];   // bin_agg[# histogram][5 (shape offset) * 3]
// Independent Spatial Coorelation          maximum value:  45
// Group Spatial Coorelation                maximum value:  48  (12* 4)
// Convex / Concave Spatial Coorelation     maximum value:  77
reg     [10:0]  bin_agg_ext [15:0];
// Independent Spatial Coorelation          maximum value:  45
// Group Spatial Coorelation                maximum value:  48
// Convex / Concave Spatial Coorelation     maximum value:1232  (77*16)

// Spatial distance calculation
// wire    [3:0]   current_peak;
wire    [1:0]   spatial_dist        [15:0][15:0];   // spatial[current spatial location][all possible peaks]
wire    [1:0]   div                 [15:0][15:0];   // helper of spatial_dist
wire    [1:0]   mod                 [15:0][15:0];   // helper of spatial_dist
wire    [1:0]   pred_spatial_dist   [15:0];
wire    [1:0]   pred_div            [15:0];
wire    [1:0]   pred_mod            [15:0];

wire    [6:0]   offset_0    [15:0];
wire    [9:0]   offset_1    [15:0];
wire    [9:0]   offset_2    [15:0];
wire    [9:0]   offset_3    [15:0];
wire    [6:0]   element_1   [15:0][ 7:0];
wire    [6:0]   element_2   [15:0][ 6:0];
wire    [6:0]   element_3   [15:0][ 6:0];
// Maximum value of offset 0:   77  (77*1)
// Maximum value of offset 1:  616  (77*8)
// Maximum value of offset 2:  539  (77*7)
// Maximum value of offset 3:  539  (77*7)
wire            in_calc_convex_state;

// Distance estimation using adjusted bins
// Temporal adjustment
reg     [10:0]  max_bin_val     [15:0];
reg     [7:0]   max_bin_dis     [15:0];
wire            in_random_or_group_state;
wire            first_mbin_cond;
wire            update_max_cond [15:0];
wire    [10:0]  updated_max_val [15:0];
wire    [7:0]   updated_max_dis [15:0];

// Spatial adjustment
reg     [10:0]  s_max_bin_val;
reg     [7:0]   s_max_bin_dis;
reg     [3:0]   s_max_bin_loc;
wire            spatial_cmp     [14:0];
wire    [10:0]  spatial_bin_val [14:0]; 
wire    [7:0]   spatial_bin_dis [14:0];
wire    [3:0]   spatial_bin_loc [14:0];

// Peak estimation using adjusted bins
reg     [10:0]  predict_peak_val;
reg     [3:0]   predict_peak_loc;
reg     [7:0]   predict_peak_dis;
reg     [1:0]   predict_type;

// ===============================================================
//                          Design
// ===============================================================
// FSM
// current state
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) current_state <= STATE_IDLE;
    else        current_state <= next_state;
end

// next state
always @(*) begin
    next_state = current_state;
    case (current_state)
        STATE_IDLE: begin
            if (in_valid && !inputtype)                 next_state = STATE_INPUT_DRAM;      // read histogram from DRAM
            else if (in_valid)                          next_state = STATE_INPUT_WAIT;      // build histogram from signals
        end
        STATE_INPUT_WAIT:  if (start)                   next_state = STATE_INPUT_SIGNAL;
        STATE_INPUT_SIGNAL: begin
            if (!in_valid)                              next_state = STATE_CALC;
            else if (!start)                            next_state = STATE_INPUT_WAIT;
        end
        STATE_INPUT_DRAM: if (rlast_m_inf)              next_state = STATE_CALC;
        STATE_CALC: if (next_calc_state == CALC_IDLE)   next_state = STATE_LOAD;
        STATE_LOAD: if (flag_finish_load)               next_state = STATE_OUTPUT_DRAM;
        STATE_OUTPUT_DRAM: if (flag_finish_w_DRAM)      next_state = STATE_IDLE;
        default:                                        next_state = current_state;
    endcase
end
assign flag_finish_load =   (cnt_buffer_arr[1] == 15);
assign flag_finish_w_DRAM = (bvalid_m_inf) && (cnt == 0);

// output logic
// According to SPEC, an extra cycle of low-signal busy is allowed after in_valid pulls low.
// The implementation here is stricter.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                                 busy <= 0;
    else if (
        ((current_state == STATE_INPUT_SIGNAL) && (!in_valid)) ||
        ((current_state == STATE_INPUT_DRAM))    
    )                                                           busy <= 1;
    else if (flag_finish_w_DRAM)                                busy <= 0;
    else                                                        busy <= busy;
end

// calculation FSM
// current calculation state
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_calc_state <= CALC_IDLE;
    else        current_calc_state <= next_calc_state;
end

// next calculation state
always @(*) begin
    next_calc_state = current_calc_state;
    if (current_state == STATE_CALC) begin
        case (current_calc_state)
            CALC_IDLE: begin
                case (type_val)
                    0:                              next_calc_state = CALC_RANDOM;
                    1:                              next_calc_state = CALC_GROUP;
                    2:                              next_calc_state = CALC_CONVEX;
                    3:                              next_calc_state = CALC_CONCAVE;
                    default:                        next_calc_state = 0;    // will not happen
                endcase
            end
            CALC_RANDOM,
            CALC_GROUP,
            CALC_CONVEX:    if (flag_finish_calc)   next_calc_state = CALC_IDLE;
            CALC_CONCAVE:   if (flag_finish_calc)   next_calc_state = CALC_CONVEX;
            default:                                next_calc_state = current_calc_state;
        endcase 
    end
end
assign flag_finish_calc =   (type_val[1]) ?
                            ((cnt_buffer_arr[24] == 235) && in_calc_buffer_arr[24]) :   // Random or Group
                            ((cnt_buffer_arr[ 7] == 250) && in_calc_buffer_arr[ 7]);    // Convex / Concave

// counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                 cnt <= 0;
    else begin
        case (current_state)
            STATE_IDLE:                         cnt <= 0;
            STATE_INPUT_WAIT:                   cnt <= start;
            STATE_INPUT_SIGNAL: begin                           // counter of bin
                if ((!in_valid) || (!start))    cnt <= 0;
                else                            cnt <= cnt_inc;
            end
            STATE_INPUT_DRAM: if (rvalid_m_inf) cnt <= cnt_inc; // counter of bin
            STATE_CALC: begin                                   // counter of cycles
                case (current_calc_state)
                    CALC_IDLE:                  cnt <= 0;
                    CALC_RANDOM,
                    CALC_GROUP,
                    CALC_CONVEX,
                    CALC_CONCAVE:               cnt <= flag_finish_calc ? 0 : cnt_inc;
                    default: ;
                endcase
            end
            STATE_LOAD: begin                                   // counter of cycles
                if (flag_finish_load)           cnt <= 0;
                else                            cnt <= cnt_inc;
            end
            STATE_OUTPUT_DRAM: begin                            // counter of burst
                if (wready_m_inf)               cnt <= cnt_inc;
                else                            cnt <= cnt;
            end
            default:                            cnt <= cnt;
        endcase
    end
end
assign cnt_inc = cnt + 1;

// counter buffer
generate
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)             cnt_buffer_arr[0] <= 0;
        else                    cnt_buffer_arr[0] <= cnt;
    end
    for (idx=1; idx<25; idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)         cnt_buffer_arr[idx] <= 0;
            else                cnt_buffer_arr[idx] <= cnt_buffer_arr[idx-1];
        end
    end
endgenerate

// the buffer array of in-calculation flag
generate
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                                 in_calc_buffer_arr[0] <= 0;
        else if (current_calc_state != CALC_IDLE)   in_calc_buffer_arr[0] <= 1;
        else                                        in_calc_buffer_arr[0] <= 0;
    end
    for (idx=1; idx<25; idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) in_calc_buffer_arr[idx] <= 0;
            else        in_calc_buffer_arr[idx] <= in_calc_buffer_arr[idx - 1];
        end
    end
endgenerate

// axi4 FSM
// current axi4 state 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_axi_state <= AXI_IDLE;
    else        current_axi_state <= next_axi_state;
end

// next axi4 state
always @(*) begin
    next_axi_state = current_axi_state;
    case (current_axi_state)
        AXI_IDLE: begin
            if (current_state == STATE_INPUT_DRAM)          next_axi_state = AXI_R_ADDR;
            else if (current_state == STATE_OUTPUT_DRAM)    next_axi_state = AXI_W_ADDR;
        end

        AXI_W_ADDR: if (awready_m_inf)                      next_axi_state = AXI_W_DATA;
        AXI_W_DATA: if (wlast_m_inf)                        next_axi_state = AXI_W_RESP;
        AXI_W_RESP: if (bvalid_m_inf)                       next_axi_state = AXI_IDLE;

        AXI_R_ADDR: if (arready_m_inf)                      next_axi_state = AXI_R_DATA;
        AXI_R_DATA: if (rlast_m_inf)                        next_axi_state = AXI_IDLE;
        default:                                            next_axi_state = current_axi_state;
    endcase
end

// metadata signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        type_val        <= 0;
        frame_id_val    <= 0;
    end
    else if ((current_state == STATE_IDLE) && (in_valid)) begin
        type_val        <= inputtype;
        frame_id_val    <= frame_id;
    end
end

// SRAM modules
generate
    for (idx=0; idx<16; idx=idx+1) begin: SRAM_loop
        BIN_MEM_200MHz U1(
            .Q(     mem_q[idx]      ),
            .CLK(   clk             ),
            .CEN(   1'b0            ),
            .WEN(   mem_wen[idx]    ),
            .A(     mem_addr        ),
            .D(     mem_data[idx]   ),
            .OEN(   1'b0            )
        );
    end
endgenerate

// SRAM signals
// Write enable negative (Write: 0, Read: 1)
generate
    for (idx=0; idx<16; idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)                         mem_wen[idx] <= 1;
            else begin
                case (current_state)
                    STATE_INPUT_SIGNAL:         mem_wen[idx] <= !write_sram_cond;                       // write every 16 bins
                    STATE_INPUT_DRAM:           mem_wen[idx] <= !((rvalid_m_inf) && (cnt[7:4] == idx)); // write 16 SRAMs in order
                    default:                    mem_wen[idx] <= 1;
                endcase
            end
        end
    end
endgenerate
assign write_sram_cond = (&(cnt[3:0])); // cnt == 15


// SRAM address
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                         mem_addr <= 0;
    else begin
        case (current_state)
            STATE_IDLE,
            STATE_INPUT_WAIT:           mem_addr <= 0;
            STATE_INPUT_SIGNAL: begin
                if (cnt[3:0] == 'd15)   mem_addr <= cnt[7:4];       // write back
                else                    mem_addr <= cnt[7:4] + 1;   //  read next
            end
            STATE_INPUT_DRAM,
            STATE_LOAD,
            STATE_OUTPUT_DRAM:          mem_addr <= cnt[3:0];
            STATE_CALC: begin
                case (current_calc_state)
                    CALC_IDLE:          mem_addr <= 0;
                    CALC_RANDOM,
                    CALC_GROUP,
                    CALC_CONVEX,
                    CALC_CONCAVE:       mem_addr <= cnt[7:4];   // mem_addr <= mem_addr + 1;
                    default: ;
                endcase                
            end
            default:                    mem_addr <= mem_addr;
        endcase
    end 
end

// SRAM data
generate
    for (idx=0; idx<16; idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)                         mem_data[idx] <= 0;
            else begin
                case (current_state)
                    STATE_INPUT_WAIT,
                    STATE_INPUT_SIGNAL: begin   // bin counting
                        if (first_bin_cond) begin
                            if (bin_zero_init)  mem_data[idx] <= {63'b0, stop[idx]};                                             // zero initalization
                            else                mem_data[idx] <= {mem_q[idx][63: 4], bin_incr[idx]};    // loading from SRAM
                        end
                        else begin
                                                mem_data[idx][63:60] <= bin_incr[idx];
                                                mem_data[idx][59: 4] <= mem_data[idx][63: 8];                           // rolling
                        end
                    end

                    // truncation: rdata_m_inf (DRAM 128 bits) --> mem_data (SRAM 64 bits)
                    STATE_INPUT_DRAM:           mem_data[idx] <=    {
                                                                        rdata_m_inf[15*8 + 3:15*8],
                                                                        rdata_m_inf[14*8 + 3:14*8],
                                                                        rdata_m_inf[13*8 + 3:13*8],
                                                                        rdata_m_inf[12*8 + 3:12*8],
                                                                        rdata_m_inf[11*8 + 3:11*8],
                                                                        rdata_m_inf[10*8 + 3:10*8],
                                                                        rdata_m_inf[ 9*8 + 3: 9*8],
                                                                        rdata_m_inf[ 8*8 + 3: 8*8],
                                                                        rdata_m_inf[ 7*8 + 3: 7*8],
                                                                        rdata_m_inf[ 6*8 + 3: 6*8],
                                                                        rdata_m_inf[ 5*8 + 3: 5*8],
                                                                        rdata_m_inf[ 4*8 + 3: 4*8],
                                                                        rdata_m_inf[ 3*8 + 3: 3*8],
                                                                        rdata_m_inf[ 2*8 + 3: 2*8],
                                                                        rdata_m_inf[ 1*8 + 3: 1*8],
                                                                        rdata_m_inf[ 0*8 + 3: 0*8]
                                                                    };                                                  // get bin-data from DRAM
                    
                    // resource sharing for distance calculation (replacing bin_agg[15:0][8:1])
                    // disabled since it may cause the difficulty when APR
                    // STATE_CALC: begin
                    //                             mem_data[idx] <=    {
                    //                                                     1'b0, bin_agg[idx][7],  // bin_agg[idx][8]
                    //                                                     1'b0, bin_agg[idx][6],  // bin_agg[idx][7]
                    //                                                     1'b0, bin_agg[idx][5],  // bin_agg[idx][6]
                    //                                                     1'b0, bin_agg[idx][4],  // bin_agg[idx][5]
                    //                                                     1'b0, bin_agg[idx][3],  // bin_agg[idx][4]
                    //                                                     1'b0, bin_agg[idx][2],  // bin_agg[idx][3]
                    //                                                     1'b0, bin_agg[idx][1],  // bin_agg[idx][2]
                    //                                                     1'b0, bin_agg[idx][0]   // bin_agg[idx][1]
                    //                                                 };
                    // end

                    // resource sharing for writing back to DRAM
                    STATE_LOAD:         if (cnt_buffer_arr[1][3:0] == idx)                      mem_data[idx] <= mem_q[0];                          // first burst data (1-16 bins for first histogram)
                    STATE_OUTPUT_DRAM:  if ((cnt_buffer_arr[1][3:0] == idx) && wready_m_inf)    mem_data[idx] <= mem_q[cnt_buffer_arr[1][7:4]+1];   // update burst data of next histogram
                    // cnt          --> cnt_buffer_arr[0]   --> cnt_buffer_arr[1]
                    // set signals  --> process signals     --> update signals
                    default: ;
                endcase
            end
        end
    end
endgenerate
assign first_bin_cond = (cnt[3:0] == 0);
generate
    for (idx=0; idx<16; idx=idx+1) assign bin_incr[idx] = ((first_bin_cond) ? mem_q[idx][ 3: 0] : mem_data[idx][ 7: 4]) + stop[idx];
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                     bin_zero_init <= 1;
    else begin
        case (current_state)
            STATE_IDLE:             bin_zero_init <= 1;
            STATE_INPUT_SIGNAL: begin
                if (!in_valid)      bin_zero_init <= 1; // reset
                else if (!start)    bin_zero_init <= 0;
            end
            default: ;
        endcase
    end
end

// AXI Signals
// AXI Read Signals
// AXI Read Address Channel
assign arid_m_inf =     4'b0;
assign arburst_m_inf =  2'b01;
assign arsize_m_inf =   3'b100;
assign arlen_m_inf =    8'd255;
assign arvalid_m_inf =  (current_axi_state == AXI_R_ADDR);  // deterministic signals to avoid unknown operation
assign araddr_m_inf =   a_rw_addr_m_inf_reg;

always @(*) begin
    a_rw_addr_m_inf_reg[31:20] = 12'h0;                            // constant 0
    a_rw_addr_m_inf_reg[19:16] = (frame_id_val[4]) ? 4'h2 : 4'h1;  // first / second half frame number
    a_rw_addr_m_inf_reg[15:12] = frame_id_val[3:0];                // remaining frame number
    a_rw_addr_m_inf_reg[11: 0] = 4'h0;                             // constant 0
end

// AXI Read Data Channel
assign rready_m_inf = 1;

// AXI Write Signals
// AXI Write Address Channel
assign awid_m_inf =     4'b0;
assign awburst_m_inf =  2'b01;
assign awsize_m_inf =   3'b100;
assign awlen_m_inf =    8'd255; // 16 burst * 16 histogram
assign awvalid_m_inf =  (current_axi_state == AXI_W_ADDR);  // deterministic signals to avoid unknown operation
assign awaddr_m_inf =   a_rw_addr_m_inf_reg;

// AXI Write Data Channel
assign wvalid_m_inf =   1;
assign wdata_m_inf =    wdata_m_inf_reg;
assign wlast_m_inf =    (current_axi_state == AXI_W_DATA) && (cnt == 255);

// AXI Write Response Channel
assign bready_m_inf = 1;

always @(*) begin
    if (cnt[3:0] == 15) begin
        // 1 offset between output distance and design index
        case (predict_type)
            0,
            1:          wdata_m_inf_reg[15*8+7:15*8] = max_bin_dis[cnt[7:4]] + 1;
            2,
            3:          wdata_m_inf_reg[15*8+7:15*8] = predict_peak_dis + pred_spatial_dist[cnt[7:4]] * ((predict_type == 2) ? 5 : -5) + 1;
            default:    wdata_m_inf_reg[15*8+7:15*8] = 0;   // will not happen
        endcase
    end 
    else                wdata_m_inf_reg[15*8+7:15*8] = {4'b0, mem_data[cnt[3:0]][15*4 +3:15*4]};

    wdata_m_inf_reg[14*8+7:14*8] = {4'b0, mem_data[cnt[3:0]][14*4 +3:14*4]};
    wdata_m_inf_reg[13*8+7:13*8] = {4'b0, mem_data[cnt[3:0]][13*4 +3:13*4]};
    wdata_m_inf_reg[12*8+7:12*8] = {4'b0, mem_data[cnt[3:0]][12*4 +3:12*4]};
    wdata_m_inf_reg[11*8+7:11*8] = {4'b0, mem_data[cnt[3:0]][11*4 +3:11*4]};
    wdata_m_inf_reg[10*8+7:10*8] = {4'b0, mem_data[cnt[3:0]][10*4 +3:10*4]};
    wdata_m_inf_reg[ 9*8+7: 9*8] = {4'b0, mem_data[cnt[3:0]][ 9*4 +3: 9*4]};
    wdata_m_inf_reg[ 8*8+7: 8*8] = {4'b0, mem_data[cnt[3:0]][ 8*4 +3: 8*4]};
    wdata_m_inf_reg[ 7*8+7: 7*8] = {4'b0, mem_data[cnt[3:0]][ 7*4 +3: 7*4]};
    wdata_m_inf_reg[ 6*8+7: 6*8] = {4'b0, mem_data[cnt[3:0]][ 6*4 +3: 6*4]};
    wdata_m_inf_reg[ 5*8+7: 5*8] = {4'b0, mem_data[cnt[3:0]][ 5*4 +3: 5*4]};
    wdata_m_inf_reg[ 4*8+7: 4*8] = {4'b0, mem_data[cnt[3:0]][ 4*4 +3: 4*4]};
    wdata_m_inf_reg[ 3*8+7: 3*8] = {4'b0, mem_data[cnt[3:0]][ 3*4 +3: 3*4]};
    wdata_m_inf_reg[ 2*8+7: 2*8] = {4'b0, mem_data[cnt[3:0]][ 2*4 +3: 2*4]};
    wdata_m_inf_reg[ 1*8+7: 1*8] = {4'b0, mem_data[cnt[3:0]][ 1*4 +3: 1*4]};
    wdata_m_inf_reg[ 0*8+7: 0*8] = {4'b0, mem_data[cnt[3:0]][ 0*4 +3: 0*4]};
    // zero padding: mem_data (SRAM 64 bits) --> wdata_m_inf (DRAM 128 bits)
end

// Distance Calculation

// Independent / Group Histogram
// Cycle                SRAM daata  bin_arr [0]     [1]     [2]     [3]     [4]     aggregation    
// Operation                                adder           adder           adder
// cnt_buf[1] == 0      X0                  X0                                                  
// cnt_buf[2] == 0      X1                  X1      X0
// cnt_buf[3] == 0      X2                  X2      X1      X02
// cnt_buf[4] == 0      X3                  X3      X2      X13     X02
// cnt_buf[5] == 0      X4                  X4      X3      X24     X13     X024
// cnt_buf[6] == 0      X5                  X5      X4      X35     X24     X135    (Group Sum)                             
// cnt_buf[7] == 0      X6                  X6      X5      X46     X35     X246    (Group Sum)     Max_Dist
// cnt_buf[7] == 1      X7                  X7      X6      X57     X46     X357    (Group Sum)     Max_Dist
// ...

// Convex / Concave Histogram
// Cycle                SRAM daata  bin_arr [0]     [1]     [2]     [3]     [4]     aggregation
// Operation                                adder1  adder4  adder3  adder2  adder1
// cnt_buf[ 1] ==  0    X0                  X0
// cnt_buf[ 2] ==  0    X1                  X1      X01
// cnt_buf[ 3] ==  0    X2                  X2      X12     X012
// cnt_buf[ 4] ==  0    X3                  X3      X23     X123    X0123
// cnt_buf[ 5] ==  0    X4                  X4      X34     X234    X1234   X01234
// cnt_buf[ 6] ==  0    X5                  X5      X45     X345    X2345   X12345  (X01234)
// cnt_buf[ 7] ==  0    X6                  X6      X56     X456    X3456   X23456
// cnt_buf[ 8] ==  0    X7                  X7      X67     X567    X4567   X34567
// cnt_buf[ 9] ==  0    X8                  X8      X78     X678    X5678   X45678
// cnt_buf[10] ==  0    X9                  X9      X89     X789    X6789   X56789
// cnt_buf[11] ==  0    XA                  XA      X9A     X89A    X789A   X6789A  (X01234 + Y56789)
// cnt_buf[12] ==  0    XB                  XB      XAB     X9AB    X89AB   X789AB
// cnt_buf[13] ==  0    XC                  XC      XBC     XABC    X9ABC   X89ABC
// cnt_buf[14] ==  0    XD                  XD      XCD     XBCD    XABCD   X9ABCD
// cnt_buf[15] ==  0    XE                  XE      XDE     XCDE    XBCDE   XABCDE
// cnt_buf[16] ==  0    XF                  XF      XEF     XDEF    XCDEF   XBCDEF  (X01234 + Y56789 + ZABCDE)
// cnt_buf[17] ==  0    XG                  XG      XFG     XEFG    XDEFG   XCDEFG
// cnt_buf[18] ==  0    XH                  XH      XGH     XFGH    XEFGH   XDEFGH
// cnt_buf[19] ==  0    XI                  XI      XHI     XGHI    XFGHI   XEFGHI
// cnt_buf[20] ==  0    XJ                  XJ      XIJ     XHIJ    XGHIJ   XFGHIJ
//*cnt_buf[21] ==  0    XK                  XK      XJK     XIJK    XHIJK   XGHIJK  X01234 + Y56789 + ZABCDE + #FGHIJ
// cnt_buf[22] ==  0    XL                  XL      XKL     XJKL    XIJKL   XHIJKL                                      16 Max_Dist (temporal)
// cnt_buf[22] ==  1    XM                  XM      XLM     XKLM    XJKLM   XIJKLM                                      16 Max_Dist (temporal)
// cnt_buf[22] ==  2    XN                  XN      XMN     XLMN    XKLMN   XJKLMN                                      16 Max_Dist (temporal)
// cnt_buf[22] ==  3    XO                  XO      XNO     XMNO    XLMNO   XKLMNO                                      16 Max_Dist (temporal)
// ...
// cnt_buf[22] == 235   ...                 ...     ...     ...     ...     ...                                         16 Max_Dist (temporal)
// cnt_buf[23] == 235   ...                 ...     ...     ...     ...     ...                                                                 1 Max_Dist (temporal + spatial)
// cnt_buf[24] == 235   ...                 ...     ...     ...     ...     ...                                                                                                 Convex / Concave prediction

// Notes: Before cycle of cnt_buf[21] == 0
//*bin_agg[14]    X01234
// bin_agg[13]    X12345
// bin_agg[12]    X23456
// bin_agg[11]    X34567
// bin_agg[10]    X45678
//*bin_agg[ 9]    X56789
// bin_agg[ 8]    X6789A
// bin_agg[ 7]    X789AB
// bin_agg[ 6]    X89ABC
// bin_agg[ 5]    X9ABCD
//*bin_agg[ 4]    XABCDE
// bin_agg[ 3]    XBCDEF
// bin_agg[ 2]    XCDEFG
// bin_agg[ 1]    XDEFGH
// bin_agg[ 0]    XEFGHI
//*bin_arr[ 4]    XFGHIJ

// Adjusted bin across time dimension (pulse function)
generate
    for (idx=0; idx<16; idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)             bin_arr[idx][0] <= 0;
            else                    bin_arr[idx][0] <= bin[idx];
        end
        for (idy=1; idy<5; idy=idy+1) begin
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)         bin_arr[idx][idy] <= 0;
                else                bin_arr[idx][idy] <= (weight_a[idy] * bin[idx]) + bin_arr[idx][idy-1];
                // else                bin_arr[idx][idy] <= a_mult_b[idx][idy] + bin_arr[idx][idy-1];    // MAC: ab+c
            end
        end
    end
endgenerate
// generate
//     for (idx=0; idx<16; idx=idx+1) begin
//         assign a_mult_b[idx][1] = !(type_val[1]) ? 0        :   bin[idx] << 2;  // 0 / 4
//         assign a_mult_b[idx][2] = !(type_val[1]) ? bin[idx] :   bin[idx] * 3;   // 1 / 3
//         assign a_mult_b[idx][3] = !(type_val[1]) ? 0        :   bin[idx] << 1;  // 0 / 2
//         assign a_mult_b[idx][4] = bin[idx];                                     // 1 / 1
//     end
// endgenerate

// Bin selection from SRAM signals for adjusted bin (bin_arr)
generate
    for (idx=0; idx<16; idx=idx+1) begin
        always @(*) begin   
            case (cnt_buffer_arr[1][3:0])
                 0:         bin[idx] = mem_q[idx][ 0*4+3: 0*4];
                 1:         bin[idx] = mem_q[idx][ 1*4+3: 1*4];
                 2:         bin[idx] = mem_q[idx][ 2*4+3: 2*4];
                 3:         bin[idx] = mem_q[idx][ 3*4+3: 3*4];
                 4:         bin[idx] = mem_q[idx][ 4*4+3: 4*4];
                 5:         bin[idx] = mem_q[idx][ 5*4+3: 5*4];
                 6:         bin[idx] = mem_q[idx][ 6*4+3: 6*4];
                 7:         bin[idx] = mem_q[idx][ 7*4+3: 7*4];
                 8:         bin[idx] = mem_q[idx][ 8*4+3: 8*4];
                 9:         bin[idx] = mem_q[idx][ 9*4+3: 9*4];
                10:         bin[idx] = mem_q[idx][10*4+3:10*4];
                11:         bin[idx] = mem_q[idx][11*4+3:11*4];
                12:         bin[idx] = mem_q[idx][12*4+3:12*4];
                13:         bin[idx] = mem_q[idx][13*4+3:13*4];
                14:         bin[idx] = mem_q[idx][14*4+3:14*4];
                15:         bin[idx] = mem_q[idx][15*4+3:15*4];
                default:    bin[idx] = 0;   // will not happen
            endcase
        end
    end
endgenerate

// Pulse Weight
always @(*) begin
    case (type_val)
        0,
        1: begin
            weight_a[1] = 0;
            weight_a[2] = 1;
            weight_a[3] = 0;
            weight_a[4] = 1;
        end
        2,
        3: begin
            weight_a[1] = 4;
            weight_a[2] = 3;
            weight_a[3] = 2;
            weight_a[4] = 1;
        end
        default: begin  // will not happen
            weight_a[1] = 0;
            weight_a[2] = 0;
            weight_a[3] = 0;
            weight_a[4] = 0;
        end
    endcase
end

// Bin aggregation (and buffers)
// Type0 & Type1
// Aggregation Result:  bin_agg     [15:0][0]
// Type2 & Type3
// Aggregation Result:  bin_agg_ext`[15:0]
// Buffer Usage:        bin_agg     [15:0][14:0]
generate
    for (idx=0; idx<16; idx=idx+1)  begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)             bin_agg[idx][0] <=      0;
            else begin
                case (current_calc_state)
                    CALC_RANDOM,
                    CALC_CONVEX,
                    CALC_CONCAVE:   bin_agg[idx][0] <=      bin_arr[idx][4];

                    CALC_GROUP:     bin_agg[idx][0] <=      bin_arr[(idx/8)*8 + ((idx/2)%2)*2 + 0][4] + 
                                                            bin_arr[(idx/8)*8 + ((idx/2)%2)*2 + 1][4] + 
                                                            bin_arr[(idx/8)*8 + ((idx/2)%2)*2 + 4][4] + 
                                                            bin_arr[(idx/8)*8 + ((idx/2)%2)*2 + 5][4];
                    // Grouping index   (idx/8)*8 + ((idx/2)%2)*2
                    // 0   0   2   2
                    // 0   0   2   2
                    // 8   8  10  10
                    // 8   8  10  10
                    default: ;
                endcase
            end
        end
        // resource sharing for distance calculation (replaced by mem_data[15:0])
        // disabled since it may cause the difficulty when APR
        // for (idy=1; idy<9; idy=idy+1) begin
        //     always @(*) begin
        //         bin_agg[idx][idy] = mem_data[idx][(idy-1)*8+6:(idy-1)*8];
        //     end
        // end
        for (idy=1; idy<15; idy=idy+1) begin
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)             bin_agg[idx][idy] <= 0;
                else                    bin_agg[idx][idy] <= bin_agg[idx][idy-1];
            end 
        end
    end
endgenerate

// Adjusted bin across spatial dimension (spatial coorelation)
generate
    for (idx=0; idx<16; idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) bin_agg_ext[idx] <= 0;
            else        bin_agg_ext[idx] <= (offset_0[idx] + offset_1[idx]) + (offset_2[idx] + offset_3[idx]);
        end
    end
endgenerate

// Spatial distance calculation
// Absolute distance between specified peak and each location
// [max(abs(peak//4 - i//4), abs(peak%4 - i%4)) for i in range(16)]
// e.g.
// peak = 0
// 0   1   2   3
// 1   1   2   3
// 2   2   2   3
// 3   3   3   3
generate
    for (idx=0; idx<16; idx=idx+1) begin
        for (idy=0; idy<16; idy=idy+1) begin
            assign spatial_dist[idx][idy] = (div[idx][idy] > mod[idx][idy]) ? div[idx][idy] : mod[idx][idy];
            assign div[idx][idy] =          (idy/4 >= idx/4) ? (idy/4 - idx/4) : (idx/4 - idy/4);   // helper of spatial_dist
            assign mod[idx][idy] =          (idy%4 >= idx%4) ? (idy%4 - idx%4) : (idx%4 - idy%4);   // helper of spatial_dist
        end
    end
endgenerate

generate
    for (idx=0; idx<16; idx=idx+1) begin
        assign pred_spatial_dist[idx] = (pred_div[idx] > pred_mod[idx]) ? pred_div[idx] : pred_mod[idx];
        assign pred_div[idx] =          (predict_peak_loc/4 >= idx/4) ? (predict_peak_loc/4 - idx/4) : (idx/4 - predict_peak_loc/4);
        assign pred_mod[idx] =          (predict_peak_loc%4 >= idx%4) ? (predict_peak_loc%4 - idx%4) : (idx%4 - predict_peak_loc%4);
    end
endgenerate

generate
    for (idx=0; idx<16; idx=idx+1) begin
        assign offset_0[idx] =  (current_calc_state == CALC_CONVEX) ? bin_agg[idx][14] : bin_arr[idx][4];
        assign offset_1[idx] =  ( (element_1[idx][0] + element_1[idx][1]) + (element_1[idx][2] + element_1[idx][3]) ) + 
                                ( (element_1[idx][4] + element_1[idx][5]) + (element_1[idx][6] + element_1[idx][7]) );
        assign offset_2[idx] =  ( (element_2[idx][0] + element_2[idx][1]) + (element_2[idx][2] + element_2[idx][3]) ) + 
                                ( (element_2[idx][4] + element_2[idx][5]) + (element_2[idx][6]) );
        assign offset_3[idx] =  ( (element_3[idx][0] + element_3[idx][1]) + (element_3[idx][2] + element_3[idx][3]) ) + 
                                ( (element_3[idx][4] + element_3[idx][5]) + (element_3[idx][6]) );
    // DW02_sum_inst OFFSET_1(
    //     .inst_INPUT(
    //         {
    //             3'b0, element_1[idx][0],
    //             3'b0, element_1[idx][1],
    //             3'b0, element_1[idx][2],
    //             3'b0, element_1[idx][3],
    //             3'b0, element_1[idx][4],
    //             3'b0, element_1[idx][5],
    //             3'b0, element_1[idx][6],
    //             3'b0, element_1[idx][7]
    //         }
    //     ),
    //     .SUM_inst(offset_1[idx])
    // );
    // DW02_sum_inst OFFSET_2(
    //     .inst_INPUT(
    //         {
    //             3'b0, element_2[idx][0],
    //             3'b0, element_2[idx][1],
    //             3'b0, element_2[idx][2],
    //             3'b0, element_2[idx][3],
    //             3'b0, element_2[idx][4],
    //             3'b0, element_2[idx][5],
    //             3'b0, element_2[idx][6],
    //             10'b0
    //         }
    //     ),
    //     .SUM_inst(offset_2[idx])
    // );
    // DW02_sum_inst OFFSET_3(
    //     .inst_INPUT(
    //         {
    //             3'b0, element_3[idx][0],
    //             3'b0, element_3[idx][1],
    //             3'b0, element_3[idx][2],
    //             3'b0, element_3[idx][3],
    //             3'b0, element_3[idx][4],
    //             3'b0, element_3[idx][5],
    //             3'b0, element_3[idx][6],
    //             10'b0
    //         }
    //     ),
    //     .SUM_inst(offset_3[idx])
    // );
    end
endgenerate

// Sptial location index for all possible peak & distances
// Peak  element_1_array
//    0:  1  4  5
//    1:  0  2  4  5  6
//    2:  1  3  5  6  7
//    3:  2  6  7
//    4:  0  1  5  8  9
//    5:  0  1  2  4  6  8  9 10
//    6:  1  2  3  5  7  9 10 11
//    7:  2  3  6 10 11
//    8:  4  5  9 12 13
//    9:  4  5  6  8 10 12 13 14
//   10:  5  6  7  9 11 13 14 15
//   11:  6  7 10 14 15
//   12:  8  9 13
//   13:  8  9 10 12 14
//   14:  9 10 11 13 15
//   15: 10 11 14

// Peak  element_2_array
//    0:  2  6  8  9 10
//    1:  3  7  8  9 10 11
//    2:  0  4  8  9 10 11
//    3:  1  5  9 10 11
//    4:  2  6 10 12 13 14
//    5:  3  7 11 12 13 14 15
//    6:  0  4  8 12 13 14 15
//    7:  1  5  9 13 14 15
//    8:  0  1  2  6 10 14
//    9:  0  1  2  3  7 11 15
//   10:  0  1  2  3  4  8 12
//   11:  1  2  3  5  9 13
//   12:  4  5  6 10 14
//   13:  4  5  6  7 11 15
//   14:  4  5  6  7  8 12
//   15:  5  6  7  9 13

// Peak  element_3_array
//    0:  3  7 11 12 13 14 15
//    1: 12 13 14 15
//    2: 12 13 14 15
//    3:  0  4  8 12 13 14 15
//    4:  3  7 11 15
//    5: 
//    6: 
//    7:  0  4  8 12
//    8:  3  7 11 15
//    9: 
//   10: 
//   11:  0  4  8 12
//   12:  0  1  2  3  7 11 15
//   13:  0  1  2  3
//   14:  0  1  2  3
//   15:  0  1  2  3  4  8 12

// Elements with distance 1 for given peak
// element_X[assumed peak][distance_matched location]
generate
    assign element_1[ 0][0] = (in_calc_convex_state) ? bin_agg[ 1][ 9] : bin_agg[ 1][ 4];
    assign element_1[ 0][1] = (in_calc_convex_state) ? bin_agg[ 4][ 9] : bin_agg[ 4][ 4];
    assign element_1[ 0][2] = (in_calc_convex_state) ? bin_agg[ 5][ 9] : bin_agg[ 5][ 4];
    assign element_1[ 0][3] = 0;
    assign element_1[ 0][4] = 0;
    assign element_1[ 0][5] = 0;
    assign element_1[ 0][6] = 0;
    assign element_1[ 0][7] = 0;

    assign element_1[ 1][0] = (in_calc_convex_state) ? bin_agg[ 0][ 9] : bin_agg[ 0][ 4];
    assign element_1[ 1][1] = (in_calc_convex_state) ? bin_agg[ 2][ 9] : bin_agg[ 2][ 4];
    assign element_1[ 1][2] = (in_calc_convex_state) ? bin_agg[ 4][ 9] : bin_agg[ 4][ 4];
    assign element_1[ 1][3] = (in_calc_convex_state) ? bin_agg[ 5][ 9] : bin_agg[ 5][ 4];
    assign element_1[ 1][4] = (in_calc_convex_state) ? bin_agg[ 6][ 9] : bin_agg[ 6][ 4];
    assign element_1[ 1][5] = 0;
    assign element_1[ 1][6] = 0;
    assign element_1[ 1][7] = 0;

    assign element_1[ 2][0] = (in_calc_convex_state) ? bin_agg[ 1][ 9] : bin_agg[ 1][ 4];
    assign element_1[ 2][1] = (in_calc_convex_state) ? bin_agg[ 3][ 9] : bin_agg[ 3][ 4];
    assign element_1[ 2][2] = (in_calc_convex_state) ? bin_agg[ 5][ 9] : bin_agg[ 5][ 4];
    assign element_1[ 2][3] = (in_calc_convex_state) ? bin_agg[ 6][ 9] : bin_agg[ 6][ 4];
    assign element_1[ 2][4] = (in_calc_convex_state) ? bin_agg[ 7][ 9] : bin_agg[ 7][ 4];
    assign element_1[ 2][5] = 0;
    assign element_1[ 2][6] = 0;
    assign element_1[ 2][7] = 0;

    assign element_1[ 3][0] = (in_calc_convex_state) ? bin_agg[ 2][ 9] : bin_agg[ 2][ 4];
    assign element_1[ 3][1] = (in_calc_convex_state) ? bin_agg[ 6][ 9] : bin_agg[ 6][ 4];
    assign element_1[ 3][2] = (in_calc_convex_state) ? bin_agg[ 7][ 9] : bin_agg[ 7][ 4];
    assign element_1[ 3][3] = 0;
    assign element_1[ 3][4] = 0;
    assign element_1[ 3][5] = 0;
    assign element_1[ 3][6] = 0;
    assign element_1[ 3][7] = 0;

    assign element_1[ 4][0] = (in_calc_convex_state) ? bin_agg[ 0][ 9] : bin_agg[ 0][ 4];
    assign element_1[ 4][1] = (in_calc_convex_state) ? bin_agg[ 1][ 9] : bin_agg[ 1][ 4];
    assign element_1[ 4][2] = (in_calc_convex_state) ? bin_agg[ 5][ 9] : bin_agg[ 5][ 4];
    assign element_1[ 4][3] = (in_calc_convex_state) ? bin_agg[ 8][ 9] : bin_agg[ 8][ 4];
    assign element_1[ 4][4] = (in_calc_convex_state) ? bin_agg[ 9][ 9] : bin_agg[ 9][ 4];
    assign element_1[ 4][5] = 0;
    assign element_1[ 4][6] = 0;
    assign element_1[ 4][7] = 0;

    assign element_1[ 5][0] = (in_calc_convex_state) ? bin_agg[ 0][ 9] : bin_agg[ 0][ 4];
    assign element_1[ 5][1] = (in_calc_convex_state) ? bin_agg[ 1][ 9] : bin_agg[ 1][ 4];
    assign element_1[ 5][2] = (in_calc_convex_state) ? bin_agg[ 2][ 9] : bin_agg[ 2][ 4];
    assign element_1[ 5][3] = (in_calc_convex_state) ? bin_agg[ 4][ 9] : bin_agg[ 4][ 4];
    assign element_1[ 5][4] = (in_calc_convex_state) ? bin_agg[ 6][ 9] : bin_agg[ 6][ 4];
    assign element_1[ 5][5] = (in_calc_convex_state) ? bin_agg[ 8][ 9] : bin_agg[ 8][ 4];
    assign element_1[ 5][6] = (in_calc_convex_state) ? bin_agg[ 9][ 9] : bin_agg[ 9][ 4];
    assign element_1[ 5][7] = (in_calc_convex_state) ? bin_agg[10][ 9] : bin_agg[10][ 4];

    assign element_1[ 6][0] = (in_calc_convex_state) ? bin_agg[ 1][ 9] : bin_agg[ 1][ 4];
    assign element_1[ 6][1] = (in_calc_convex_state) ? bin_agg[ 2][ 9] : bin_agg[ 2][ 4];
    assign element_1[ 6][2] = (in_calc_convex_state) ? bin_agg[ 3][ 9] : bin_agg[ 3][ 4];
    assign element_1[ 6][3] = (in_calc_convex_state) ? bin_agg[ 5][ 9] : bin_agg[ 5][ 4];
    assign element_1[ 6][4] = (in_calc_convex_state) ? bin_agg[ 7][ 9] : bin_agg[ 7][ 4];
    assign element_1[ 6][5] = (in_calc_convex_state) ? bin_agg[ 9][ 9] : bin_agg[ 9][ 4];
    assign element_1[ 6][6] = (in_calc_convex_state) ? bin_agg[10][ 9] : bin_agg[10][ 4];
    assign element_1[ 6][7] = (in_calc_convex_state) ? bin_agg[11][ 9] : bin_agg[11][ 4];

    assign element_1[ 7][0] = (in_calc_convex_state) ? bin_agg[ 2][ 9] : bin_agg[ 2][ 4];
    assign element_1[ 7][1] = (in_calc_convex_state) ? bin_agg[ 3][ 9] : bin_agg[ 3][ 4];
    assign element_1[ 7][2] = (in_calc_convex_state) ? bin_agg[ 6][ 9] : bin_agg[ 6][ 4];
    assign element_1[ 7][3] = (in_calc_convex_state) ? bin_agg[10][ 9] : bin_agg[10][ 4];
    assign element_1[ 7][4] = (in_calc_convex_state) ? bin_agg[11][ 9] : bin_agg[11][ 4];
    assign element_1[ 7][5] = 0;
    assign element_1[ 7][6] = 0;
    assign element_1[ 7][7] = 0;

    assign element_1[ 8][0] = (in_calc_convex_state) ? bin_agg[ 4][ 9] : bin_agg[ 4][ 4];
    assign element_1[ 8][1] = (in_calc_convex_state) ? bin_agg[ 5][ 9] : bin_agg[ 5][ 4];
    assign element_1[ 8][2] = (in_calc_convex_state) ? bin_agg[ 9][ 9] : bin_agg[ 9][ 4];
    assign element_1[ 8][3] = (in_calc_convex_state) ? bin_agg[12][ 9] : bin_agg[12][ 4];
    assign element_1[ 8][4] = (in_calc_convex_state) ? bin_agg[13][ 9] : bin_agg[13][ 4];
    assign element_1[ 8][5] = 0;
    assign element_1[ 8][6] = 0;
    assign element_1[ 8][7] = 0;

    assign element_1[ 9][0] = (in_calc_convex_state) ? bin_agg[ 4][ 9] : bin_agg[ 4][ 4];
    assign element_1[ 9][1] = (in_calc_convex_state) ? bin_agg[ 5][ 9] : bin_agg[ 5][ 4];
    assign element_1[ 9][2] = (in_calc_convex_state) ? bin_agg[ 6][ 9] : bin_agg[ 6][ 4];
    assign element_1[ 9][3] = (in_calc_convex_state) ? bin_agg[ 8][ 9] : bin_agg[ 8][ 4];
    assign element_1[ 9][4] = (in_calc_convex_state) ? bin_agg[10][ 9] : bin_agg[10][ 4];
    assign element_1[ 9][5] = (in_calc_convex_state) ? bin_agg[12][ 9] : bin_agg[12][ 4];
    assign element_1[ 9][6] = (in_calc_convex_state) ? bin_agg[13][ 9] : bin_agg[13][ 4];
    assign element_1[ 9][7] = (in_calc_convex_state) ? bin_agg[14][ 9] : bin_agg[14][ 4];

    assign element_1[10][0] = (in_calc_convex_state) ? bin_agg[ 5][ 9] : bin_agg[ 5][ 4];
    assign element_1[10][1] = (in_calc_convex_state) ? bin_agg[ 6][ 9] : bin_agg[ 6][ 4];
    assign element_1[10][2] = (in_calc_convex_state) ? bin_agg[ 7][ 9] : bin_agg[ 7][ 4];
    assign element_1[10][3] = (in_calc_convex_state) ? bin_agg[ 9][ 9] : bin_agg[ 9][ 4];
    assign element_1[10][4] = (in_calc_convex_state) ? bin_agg[11][ 9] : bin_agg[11][ 4];
    assign element_1[10][5] = (in_calc_convex_state) ? bin_agg[13][ 9] : bin_agg[13][ 4];
    assign element_1[10][6] = (in_calc_convex_state) ? bin_agg[14][ 9] : bin_agg[14][ 4];
    assign element_1[10][7] = (in_calc_convex_state) ? bin_agg[15][ 9] : bin_agg[15][ 4];

    assign element_1[11][0] = (in_calc_convex_state) ? bin_agg[ 6][ 9] : bin_agg[ 6][ 4];
    assign element_1[11][1] = (in_calc_convex_state) ? bin_agg[ 7][ 9] : bin_agg[ 7][ 4];
    assign element_1[11][2] = (in_calc_convex_state) ? bin_agg[10][ 9] : bin_agg[10][ 4];
    assign element_1[11][3] = (in_calc_convex_state) ? bin_agg[14][ 9] : bin_agg[14][ 4];
    assign element_1[11][4] = (in_calc_convex_state) ? bin_agg[15][ 9] : bin_agg[15][ 4];
    assign element_1[11][5] = 0;
    assign element_1[11][6] = 0;
    assign element_1[11][7] = 0;

    assign element_1[12][0] = (in_calc_convex_state) ? bin_agg[ 8][ 9] : bin_agg[ 8][ 4];
    assign element_1[12][1] = (in_calc_convex_state) ? bin_agg[ 9][ 9] : bin_agg[ 9][ 4];
    assign element_1[12][2] = (in_calc_convex_state) ? bin_agg[13][ 9] : bin_agg[13][ 4];
    assign element_1[12][3] = 0;
    assign element_1[12][4] = 0;
    assign element_1[12][5] = 0;
    assign element_1[12][6] = 0;
    assign element_1[12][7] = 0;

    assign element_1[13][0] = (in_calc_convex_state) ? bin_agg[ 8][ 9] : bin_agg[ 8][ 4];
    assign element_1[13][1] = (in_calc_convex_state) ? bin_agg[ 9][ 9] : bin_agg[ 9][ 4];
    assign element_1[13][2] = (in_calc_convex_state) ? bin_agg[10][ 9] : bin_agg[10][ 4];
    assign element_1[13][3] = (in_calc_convex_state) ? bin_agg[12][ 9] : bin_agg[12][ 4];
    assign element_1[13][4] = (in_calc_convex_state) ? bin_agg[14][ 9] : bin_agg[14][ 4];
    assign element_1[13][5] = 0;
    assign element_1[13][6] = 0;
    assign element_1[13][7] = 0;

    assign element_1[14][0] = (in_calc_convex_state) ? bin_agg[ 9][ 9] : bin_agg[ 9][ 4];
    assign element_1[14][1] = (in_calc_convex_state) ? bin_agg[10][ 9] : bin_agg[10][ 4];
    assign element_1[14][2] = (in_calc_convex_state) ? bin_agg[11][ 9] : bin_agg[11][ 4];
    assign element_1[14][3] = (in_calc_convex_state) ? bin_agg[13][ 9] : bin_agg[13][ 4];
    assign element_1[14][4] = (in_calc_convex_state) ? bin_agg[15][ 9] : bin_agg[15][ 4];
    assign element_1[14][5] = 0;
    assign element_1[14][6] = 0;
    assign element_1[14][7] = 0;

    assign element_1[15][0] = (in_calc_convex_state) ? bin_agg[10][ 9] : bin_agg[10][ 4];
    assign element_1[15][1] = (in_calc_convex_state) ? bin_agg[11][ 9] : bin_agg[11][ 4];
    assign element_1[15][2] = (in_calc_convex_state) ? bin_agg[14][ 9] : bin_agg[14][ 4];
    assign element_1[15][3] = 0;
    assign element_1[15][4] = 0;
    assign element_1[15][5] = 0;
    assign element_1[15][6] = 0;
    assign element_1[15][7] = 0;

    assign element_2[ 0][0] = (in_calc_convex_state) ? bin_agg[ 2][ 4] : bin_agg[ 2][ 9];
    assign element_2[ 0][1] = (in_calc_convex_state) ? bin_agg[ 6][ 4] : bin_agg[ 6][ 9];
    assign element_2[ 0][2] = (in_calc_convex_state) ? bin_agg[ 8][ 4] : bin_agg[ 8][ 9];
    assign element_2[ 0][3] = (in_calc_convex_state) ? bin_agg[ 9][ 4] : bin_agg[ 9][ 9];
    assign element_2[ 0][4] = (in_calc_convex_state) ? bin_agg[10][ 4] : bin_agg[10][ 9];
    assign element_2[ 0][5] = 0;
    assign element_2[ 0][6] = 0;

    assign element_2[ 1][0] = (in_calc_convex_state) ? bin_agg[ 3][ 4] : bin_agg[ 3][ 9];
    assign element_2[ 1][1] = (in_calc_convex_state) ? bin_agg[ 7][ 4] : bin_agg[ 7][ 9];
    assign element_2[ 1][2] = (in_calc_convex_state) ? bin_agg[ 8][ 4] : bin_agg[ 8][ 9];
    assign element_2[ 1][3] = (in_calc_convex_state) ? bin_agg[ 9][ 4] : bin_agg[ 9][ 9];
    assign element_2[ 1][4] = (in_calc_convex_state) ? bin_agg[10][ 4] : bin_agg[10][ 9];
    assign element_2[ 1][5] = (in_calc_convex_state) ? bin_agg[11][ 4] : bin_agg[11][ 9];
    assign element_2[ 1][6] = 0;

    assign element_2[ 2][0] = (in_calc_convex_state) ? bin_agg[ 0][ 4] : bin_agg[ 0][ 9];
    assign element_2[ 2][1] = (in_calc_convex_state) ? bin_agg[ 4][ 4] : bin_agg[ 4][ 9];
    assign element_2[ 2][2] = (in_calc_convex_state) ? bin_agg[ 8][ 4] : bin_agg[ 8][ 9];
    assign element_2[ 2][3] = (in_calc_convex_state) ? bin_agg[ 9][ 4] : bin_agg[ 9][ 9];
    assign element_2[ 2][4] = (in_calc_convex_state) ? bin_agg[10][ 4] : bin_agg[10][ 9];
    assign element_2[ 2][5] = (in_calc_convex_state) ? bin_agg[11][ 4] : bin_agg[11][ 9];
    assign element_2[ 2][6] = 0;

    assign element_2[ 3][0] = (in_calc_convex_state) ? bin_agg[ 1][ 4] : bin_agg[ 1][ 9];
    assign element_2[ 3][1] = (in_calc_convex_state) ? bin_agg[ 5][ 4] : bin_agg[ 5][ 9];
    assign element_2[ 3][2] = (in_calc_convex_state) ? bin_agg[ 9][ 4] : bin_agg[ 9][ 9];
    assign element_2[ 3][3] = (in_calc_convex_state) ? bin_agg[10][ 4] : bin_agg[10][ 9];
    assign element_2[ 3][4] = (in_calc_convex_state) ? bin_agg[11][ 4] : bin_agg[11][ 9];
    assign element_2[ 3][5] = 0;
    assign element_2[ 3][6] = 0;

    assign element_2[ 4][0] = (in_calc_convex_state) ? bin_agg[ 2][ 4] : bin_agg[ 2][ 9];
    assign element_2[ 4][1] = (in_calc_convex_state) ? bin_agg[ 6][ 4] : bin_agg[ 6][ 9];
    assign element_2[ 4][2] = (in_calc_convex_state) ? bin_agg[10][ 4] : bin_agg[10][ 9];
    assign element_2[ 4][3] = (in_calc_convex_state) ? bin_agg[12][ 4] : bin_agg[12][ 9];
    assign element_2[ 4][4] = (in_calc_convex_state) ? bin_agg[13][ 4] : bin_agg[13][ 9];
    assign element_2[ 4][5] = (in_calc_convex_state) ? bin_agg[14][ 4] : bin_agg[14][ 9];
    assign element_2[ 4][6] = 0;

    assign element_2[ 5][0] = (in_calc_convex_state) ? bin_agg[ 3][ 4] : bin_agg[ 3][ 9];
    assign element_2[ 5][1] = (in_calc_convex_state) ? bin_agg[ 7][ 4] : bin_agg[ 7][ 9];
    assign element_2[ 5][2] = (in_calc_convex_state) ? bin_agg[11][ 4] : bin_agg[11][ 9];
    assign element_2[ 5][3] = (in_calc_convex_state) ? bin_agg[12][ 4] : bin_agg[12][ 9];
    assign element_2[ 5][4] = (in_calc_convex_state) ? bin_agg[13][ 4] : bin_agg[13][ 9];
    assign element_2[ 5][5] = (in_calc_convex_state) ? bin_agg[14][ 4] : bin_agg[14][ 9];
    assign element_2[ 5][6] = (in_calc_convex_state) ? bin_agg[15][ 4] : bin_agg[15][ 9];

    assign element_2[ 6][0] = (in_calc_convex_state) ? bin_agg[ 0][ 4] : bin_agg[ 0][ 9];
    assign element_2[ 6][1] = (in_calc_convex_state) ? bin_agg[ 4][ 4] : bin_agg[ 4][ 9];
    assign element_2[ 6][2] = (in_calc_convex_state) ? bin_agg[ 8][ 4] : bin_agg[ 8][ 9];
    assign element_2[ 6][3] = (in_calc_convex_state) ? bin_agg[12][ 4] : bin_agg[12][ 9];
    assign element_2[ 6][4] = (in_calc_convex_state) ? bin_agg[13][ 4] : bin_agg[13][ 9];
    assign element_2[ 6][5] = (in_calc_convex_state) ? bin_agg[14][ 4] : bin_agg[14][ 9];
    assign element_2[ 6][6] = (in_calc_convex_state) ? bin_agg[15][ 4] : bin_agg[15][ 9];

    assign element_2[ 7][0] = (in_calc_convex_state) ? bin_agg[ 1][ 4] : bin_agg[ 1][ 9];
    assign element_2[ 7][1] = (in_calc_convex_state) ? bin_agg[ 5][ 4] : bin_agg[ 5][ 9];
    assign element_2[ 7][2] = (in_calc_convex_state) ? bin_agg[ 9][ 4] : bin_agg[ 9][ 9];
    assign element_2[ 7][3] = (in_calc_convex_state) ? bin_agg[13][ 4] : bin_agg[13][ 9];
    assign element_2[ 7][4] = (in_calc_convex_state) ? bin_agg[14][ 4] : bin_agg[14][ 9];
    assign element_2[ 7][5] = (in_calc_convex_state) ? bin_agg[15][ 4] : bin_agg[15][ 9];
    assign element_2[ 7][6] = 0;

    assign element_2[ 8][0] = (in_calc_convex_state) ? bin_agg[ 0][ 4] : bin_agg[ 0][ 9];
    assign element_2[ 8][1] = (in_calc_convex_state) ? bin_agg[ 1][ 4] : bin_agg[ 1][ 9];
    assign element_2[ 8][2] = (in_calc_convex_state) ? bin_agg[ 2][ 4] : bin_agg[ 2][ 9];
    assign element_2[ 8][3] = (in_calc_convex_state) ? bin_agg[ 6][ 4] : bin_agg[ 6][ 9];
    assign element_2[ 8][4] = (in_calc_convex_state) ? bin_agg[10][ 4] : bin_agg[10][ 9];
    assign element_2[ 8][5] = (in_calc_convex_state) ? bin_agg[14][ 4] : bin_agg[14][ 9];
    assign element_2[ 8][6] = 0;

    assign element_2[ 9][0] = (in_calc_convex_state) ? bin_agg[ 0][ 4] : bin_agg[ 0][ 9];
    assign element_2[ 9][1] = (in_calc_convex_state) ? bin_agg[ 1][ 4] : bin_agg[ 1][ 9];
    assign element_2[ 9][2] = (in_calc_convex_state) ? bin_agg[ 2][ 4] : bin_agg[ 2][ 9];
    assign element_2[ 9][3] = (in_calc_convex_state) ? bin_agg[ 3][ 4] : bin_agg[ 3][ 9];
    assign element_2[ 9][4] = (in_calc_convex_state) ? bin_agg[ 7][ 4] : bin_agg[ 7][ 9];
    assign element_2[ 9][5] = (in_calc_convex_state) ? bin_agg[11][ 4] : bin_agg[11][ 9];
    assign element_2[ 9][6] = (in_calc_convex_state) ? bin_agg[15][ 4] : bin_agg[15][ 9];

    assign element_2[10][0] = (in_calc_convex_state) ? bin_agg[ 0][ 4] : bin_agg[ 0][ 9];
    assign element_2[10][1] = (in_calc_convex_state) ? bin_agg[ 1][ 4] : bin_agg[ 1][ 9];
    assign element_2[10][2] = (in_calc_convex_state) ? bin_agg[ 2][ 4] : bin_agg[ 2][ 9];
    assign element_2[10][3] = (in_calc_convex_state) ? bin_agg[ 3][ 4] : bin_agg[ 3][ 9];
    assign element_2[10][4] = (in_calc_convex_state) ? bin_agg[ 4][ 4] : bin_agg[ 4][ 9];
    assign element_2[10][5] = (in_calc_convex_state) ? bin_agg[ 8][ 4] : bin_agg[ 8][ 9];
    assign element_2[10][6] = (in_calc_convex_state) ? bin_agg[12][ 4] : bin_agg[12][ 9];

    assign element_2[11][0] = (in_calc_convex_state) ? bin_agg[ 1][ 4] : bin_agg[ 1][ 9];
    assign element_2[11][1] = (in_calc_convex_state) ? bin_agg[ 2][ 4] : bin_agg[ 2][ 9];
    assign element_2[11][2] = (in_calc_convex_state) ? bin_agg[ 3][ 4] : bin_agg[ 3][ 9];
    assign element_2[11][3] = (in_calc_convex_state) ? bin_agg[ 5][ 4] : bin_agg[ 5][ 9];
    assign element_2[11][4] = (in_calc_convex_state) ? bin_agg[ 9][ 4] : bin_agg[ 9][ 9];
    assign element_2[11][5] = (in_calc_convex_state) ? bin_agg[13][ 4] : bin_agg[13][ 9];
    assign element_2[11][6] = 0;

    assign element_2[12][0] = (in_calc_convex_state) ? bin_agg[ 4][ 4] : bin_agg[ 4][ 9];
    assign element_2[12][1] = (in_calc_convex_state) ? bin_agg[ 5][ 4] : bin_agg[ 5][ 9];
    assign element_2[12][2] = (in_calc_convex_state) ? bin_agg[ 6][ 4] : bin_agg[ 6][ 9];
    assign element_2[12][3] = (in_calc_convex_state) ? bin_agg[10][ 4] : bin_agg[10][ 9];
    assign element_2[12][4] = (in_calc_convex_state) ? bin_agg[14][ 4] : bin_agg[14][ 9];
    assign element_2[12][5] = 0;
    assign element_2[12][6] = 0;

    assign element_2[13][0] = (in_calc_convex_state) ? bin_agg[ 4][ 4] : bin_agg[ 4][ 9];
    assign element_2[13][1] = (in_calc_convex_state) ? bin_agg[ 5][ 4] : bin_agg[ 5][ 9];
    assign element_2[13][2] = (in_calc_convex_state) ? bin_agg[ 6][ 4] : bin_agg[ 6][ 9];
    assign element_2[13][3] = (in_calc_convex_state) ? bin_agg[ 7][ 4] : bin_agg[ 7][ 9];
    assign element_2[13][4] = (in_calc_convex_state) ? bin_agg[11][ 4] : bin_agg[11][ 9];
    assign element_2[13][5] = (in_calc_convex_state) ? bin_agg[15][ 4] : bin_agg[15][ 9];
    assign element_2[13][6] = 0;

    assign element_2[14][0] = (in_calc_convex_state) ? bin_agg[ 4][ 4] : bin_agg[ 4][ 9];
    assign element_2[14][1] = (in_calc_convex_state) ? bin_agg[ 5][ 4] : bin_agg[ 5][ 9];
    assign element_2[14][2] = (in_calc_convex_state) ? bin_agg[ 6][ 4] : bin_agg[ 6][ 9];
    assign element_2[14][3] = (in_calc_convex_state) ? bin_agg[ 7][ 4] : bin_agg[ 7][ 9];
    assign element_2[14][4] = (in_calc_convex_state) ? bin_agg[ 8][ 4] : bin_agg[ 8][ 9];
    assign element_2[14][5] = (in_calc_convex_state) ? bin_agg[12][ 4] : bin_agg[12][ 9];
    assign element_2[14][6] = 0;

    assign element_2[15][0] = (in_calc_convex_state) ? bin_agg[ 5][ 4] : bin_agg[ 5][ 9];
    assign element_2[15][1] = (in_calc_convex_state) ? bin_agg[ 6][ 4] : bin_agg[ 6][ 9];
    assign element_2[15][2] = (in_calc_convex_state) ? bin_agg[ 7][ 4] : bin_agg[ 7][ 9];
    assign element_2[15][3] = (in_calc_convex_state) ? bin_agg[ 9][ 4] : bin_agg[ 9][ 9];
    assign element_2[15][4] = (in_calc_convex_state) ? bin_agg[13][ 4] : bin_agg[13][ 9];
    assign element_2[15][5] = 0;
    assign element_2[15][6] = 0;

    assign element_3[ 0][0] = (in_calc_convex_state) ? bin_arr[ 3][4] : bin_agg[ 3][14];
    assign element_3[ 0][1] = (in_calc_convex_state) ? bin_arr[ 7][4] : bin_agg[ 7][14];
    assign element_3[ 0][2] = (in_calc_convex_state) ? bin_arr[11][4] : bin_agg[11][14];
    assign element_3[ 0][3] = (in_calc_convex_state) ? bin_arr[12][4] : bin_agg[12][14];
    assign element_3[ 0][4] = (in_calc_convex_state) ? bin_arr[13][4] : bin_agg[13][14];
    assign element_3[ 0][5] = (in_calc_convex_state) ? bin_arr[14][4] : bin_agg[14][14];
    assign element_3[ 0][6] = (in_calc_convex_state) ? bin_arr[15][4] : bin_agg[15][14];

    assign element_3[ 1][0] = (in_calc_convex_state) ? bin_arr[12][4] : bin_agg[12][14];
    assign element_3[ 1][1] = (in_calc_convex_state) ? bin_arr[13][4] : bin_agg[13][14];
    assign element_3[ 1][2] = (in_calc_convex_state) ? bin_arr[14][4] : bin_agg[14][14];
    assign element_3[ 1][3] = (in_calc_convex_state) ? bin_arr[15][4] : bin_agg[15][14];
    assign element_3[ 1][4] = 0;
    assign element_3[ 1][5] = 0;
    assign element_3[ 1][6] = 0;

    assign element_3[ 2][0] = (in_calc_convex_state) ? bin_arr[12][4] : bin_agg[12][14];
    assign element_3[ 2][1] = (in_calc_convex_state) ? bin_arr[13][4] : bin_agg[13][14];
    assign element_3[ 2][2] = (in_calc_convex_state) ? bin_arr[14][4] : bin_agg[14][14];
    assign element_3[ 2][3] = (in_calc_convex_state) ? bin_arr[15][4] : bin_agg[15][14];
    assign element_3[ 2][4] = 0;
    assign element_3[ 2][5] = 0;
    assign element_3[ 2][6] = 0;

    assign element_3[ 3][0] = (in_calc_convex_state) ? bin_arr[ 0][4] : bin_agg[ 0][14];
    assign element_3[ 3][1] = (in_calc_convex_state) ? bin_arr[ 4][4] : bin_agg[ 4][14];
    assign element_3[ 3][2] = (in_calc_convex_state) ? bin_arr[ 8][4] : bin_agg[ 8][14];
    assign element_3[ 3][3] = (in_calc_convex_state) ? bin_arr[12][4] : bin_agg[12][14];
    assign element_3[ 3][4] = (in_calc_convex_state) ? bin_arr[13][4] : bin_agg[13][14];
    assign element_3[ 3][5] = (in_calc_convex_state) ? bin_arr[14][4] : bin_agg[14][14];
    assign element_3[ 3][6] = (in_calc_convex_state) ? bin_arr[15][4] : bin_agg[15][14];

    assign element_3[ 4][0] = (in_calc_convex_state) ? bin_arr[ 3][4] : bin_agg[ 3][14];
    assign element_3[ 4][1] = (in_calc_convex_state) ? bin_arr[ 7][4] : bin_agg[ 7][14];
    assign element_3[ 4][2] = (in_calc_convex_state) ? bin_arr[11][4] : bin_agg[11][14];
    assign element_3[ 4][3] = (in_calc_convex_state) ? bin_arr[15][4] : bin_agg[15][14];
    assign element_3[ 4][4] = 0;
    assign element_3[ 4][5] = 0;
    assign element_3[ 4][6] = 0;

    assign element_3[ 5][0] = 0;
    assign element_3[ 5][1] = 0;
    assign element_3[ 5][2] = 0;
    assign element_3[ 5][3] = 0;
    assign element_3[ 5][4] = 0;
    assign element_3[ 5][5] = 0;
    assign element_3[ 5][6] = 0;

    assign element_3[ 6][0] = 0;
    assign element_3[ 6][1] = 0;
    assign element_3[ 6][2] = 0;
    assign element_3[ 6][3] = 0;
    assign element_3[ 6][4] = 0;
    assign element_3[ 6][5] = 0;
    assign element_3[ 6][6] = 0;

    assign element_3[ 7][0] = (in_calc_convex_state) ? bin_arr[ 0][4] : bin_agg[ 0][14];
    assign element_3[ 7][1] = (in_calc_convex_state) ? bin_arr[ 4][4] : bin_agg[ 4][14];
    assign element_3[ 7][2] = (in_calc_convex_state) ? bin_arr[ 8][4] : bin_agg[ 8][14];
    assign element_3[ 7][3] = (in_calc_convex_state) ? bin_arr[12][4] : bin_agg[12][14];
    assign element_3[ 7][4] = 0;
    assign element_3[ 7][5] = 0;
    assign element_3[ 7][6] = 0;

    assign element_3[ 8][0] = (in_calc_convex_state) ? bin_arr[ 3][4] : bin_agg[ 3][14];
    assign element_3[ 8][1] = (in_calc_convex_state) ? bin_arr[ 7][4] : bin_agg[ 7][14];
    assign element_3[ 8][2] = (in_calc_convex_state) ? bin_arr[11][4] : bin_agg[11][14];
    assign element_3[ 8][3] = (in_calc_convex_state) ? bin_arr[15][4] : bin_agg[15][14];
    assign element_3[ 8][4] = 0;
    assign element_3[ 8][5] = 0;
    assign element_3[ 8][6] = 0;

    assign element_3[ 9][0] = 0;
    assign element_3[ 9][1] = 0;
    assign element_3[ 9][2] = 0;
    assign element_3[ 9][3] = 0;
    assign element_3[ 9][4] = 0;
    assign element_3[ 9][5] = 0;
    assign element_3[ 9][6] = 0;

    assign element_3[10][0] = 0;
    assign element_3[10][1] = 0;
    assign element_3[10][2] = 0;
    assign element_3[10][3] = 0;
    assign element_3[10][4] = 0;
    assign element_3[10][5] = 0;
    assign element_3[10][6] = 0;

    assign element_3[11][0] = (in_calc_convex_state) ? bin_arr[ 0][4] : bin_agg[ 0][14];
    assign element_3[11][1] = (in_calc_convex_state) ? bin_arr[ 4][4] : bin_agg[ 4][14];
    assign element_3[11][2] = (in_calc_convex_state) ? bin_arr[ 8][4] : bin_agg[ 8][14];
    assign element_3[11][3] = (in_calc_convex_state) ? bin_arr[12][4] : bin_agg[12][14];
    assign element_3[11][4] = 0;
    assign element_3[11][5] = 0;
    assign element_3[11][6] = 0;

    assign element_3[12][0] = (in_calc_convex_state) ? bin_arr[ 0][4] : bin_agg[ 0][14];
    assign element_3[12][1] = (in_calc_convex_state) ? bin_arr[ 1][4] : bin_agg[ 1][14];
    assign element_3[12][2] = (in_calc_convex_state) ? bin_arr[ 2][4] : bin_agg[ 2][14];
    assign element_3[12][3] = (in_calc_convex_state) ? bin_arr[ 3][4] : bin_agg[ 3][14];
    assign element_3[12][4] = (in_calc_convex_state) ? bin_arr[ 7][4] : bin_agg[ 7][14];
    assign element_3[12][5] = (in_calc_convex_state) ? bin_arr[11][4] : bin_agg[11][14];
    assign element_3[12][6] = (in_calc_convex_state) ? bin_arr[15][4] : bin_agg[15][14];

    assign element_3[13][0] = (in_calc_convex_state) ? bin_arr[ 0][4] : bin_agg[ 0][14];
    assign element_3[13][1] = (in_calc_convex_state) ? bin_arr[ 1][4] : bin_agg[ 1][14];
    assign element_3[13][2] = (in_calc_convex_state) ? bin_arr[ 2][4] : bin_agg[ 2][14];
    assign element_3[13][3] = (in_calc_convex_state) ? bin_arr[ 3][4] : bin_agg[ 3][14];
    assign element_3[13][4] = 0;
    assign element_3[13][5] = 0;
    assign element_3[13][6] = 0;

    assign element_3[14][0] = (in_calc_convex_state) ? bin_arr[ 0][4] : bin_agg[ 0][14];
    assign element_3[14][1] = (in_calc_convex_state) ? bin_arr[ 1][4] : bin_agg[ 1][14];
    assign element_3[14][2] = (in_calc_convex_state) ? bin_arr[ 2][4] : bin_agg[ 2][14];
    assign element_3[14][3] = (in_calc_convex_state) ? bin_arr[ 3][4] : bin_agg[ 3][14];
    assign element_3[14][4] = 0;
    assign element_3[14][5] = 0;
    assign element_3[14][6] = 0;

    assign element_3[15][0] = (in_calc_convex_state) ? bin_arr[ 0][4] : bin_agg[ 0][14];
    assign element_3[15][1] = (in_calc_convex_state) ? bin_arr[ 1][4] : bin_agg[ 1][14];
    assign element_3[15][2] = (in_calc_convex_state) ? bin_arr[ 2][4] : bin_agg[ 2][14];
    assign element_3[15][3] = (in_calc_convex_state) ? bin_arr[ 3][4] : bin_agg[ 3][14];
    assign element_3[15][4] = (in_calc_convex_state) ? bin_arr[ 4][4] : bin_agg[ 4][14];
    assign element_3[15][5] = (in_calc_convex_state) ? bin_arr[ 8][4] : bin_agg[ 8][14];
    assign element_3[15][6] = (in_calc_convex_state) ? bin_arr[12][4] : bin_agg[12][14];
endgenerate
assign in_calc_convex_state = (current_calc_state == CALC_CONVEX);
// Distance estimation using adjusted bins
// Consider the update condition if two bin is same
// Temporal adjustment
generate
    for (idx=0; idx<16; idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                max_bin_val[idx] <= 0;
                max_bin_dis[idx] <= 0;
            end
            else if (current_state == STATE_IDLE) begin // reset after writing back to DRAM
                max_bin_val[idx] <= 0;
                max_bin_dis[idx] <= 0;
            end
            else begin
                case (current_calc_state)
                    CALC_RANDOM,
                    CALC_GROUP,
                    CALC_CONVEX,
                    CALC_CONCAVE: begin
                        if (first_mbin_cond || update_max_cond[idx]) begin
                            max_bin_val[idx] <= updated_max_val[idx];
                            max_bin_dis[idx] <= updated_max_dis[idx];
                        end
                    end
                    default: ;
                endcase
                // case (current_calc_state)
                //     CALC_RANDOM,
                //     CALC_GROUP:     if ((cnt_buffer_arr[ 7] == 0) || (bin_agg[idx][0] > max_bin_val[idx])) begin
                //         max_bin_val[idx] <= bin_agg[idx][0];
                //         max_bin_dis[idx] <= cnt_buffer_arr[ 7];
                //     end
                //     CALC_CONVEX:    if ((cnt_buffer_arr[22] == 0) || (bin_agg_ext[idx] > max_bin_val[idx])) begin
                //         max_bin_val[idx] <= bin_agg_ext[idx];
                //         max_bin_dis[idx] <= cnt_buffer_arr[22];
                //     end
                //     CALC_CONCAVE:   if ((cnt_buffer_arr[22] == 0) || (bin_agg_ext[idx] > max_bin_val[idx])) begin
                //         max_bin_val[idx] <= bin_agg_ext[idx];
                //         max_bin_dis[idx] <= cnt_buffer_arr[ 7]; // adjust the offset from corner to peak for concave shape
                //     end
                //     default: ;
                // endcase
            end
        end
    end
endgenerate
assign in_random_or_group_state = current_calc_state[0] ^ current_calc_state[1];
assign first_mbin_cond = ( in_random_or_group_state ? cnt_buffer_arr[ 7] : cnt_buffer_arr[22] ) == 0;
generate
    for (idx=0; idx<16; idx=idx+1) begin
        assign update_max_cond[idx] = ( in_random_or_group_state ? bin_agg[idx][0] : bin_agg_ext[idx] ) > max_bin_val[idx];
        assign updated_max_val[idx] = ( in_random_or_group_state ? bin_agg[idx][0] : bin_agg_ext[idx] );
        assign updated_max_dis[idx] = (current_calc_state[0] && current_calc_state[1]) ? cnt_buffer_arr[22] : cnt_buffer_arr[ 7];
    end
endgenerate

// Spatial adjustment
// spatial_cmp[ 0] -->  bin[ 0] &  bin[ 1]
// spatial_cmp[ 1] -->  bin[ 2] &  bin[ 3]
// spatial_cmp[ 2] -->  bin[ 4] &  bin[ 5]
// spatial_cmp[ 3] -->  bin[ 6] &  bin[ 7]
// spatial_cmp[ 4] -->  bin[ 8] &  bin[ 9]
// spatial_cmp[ 5] -->  bin[10] &  bin[11]
// spatial_cmp[ 6] -->  bin[12] &  bin[13]
// spatial_cmp[ 7] -->  bin[14] &  bin[15]

// spatial_cmp[ 8] --> sbin[ 0] & sbin[ 1]
// spatial_cmp[ 9] --> sbin[ 2] & sbin[ 3]
// spatial_cmp[10] --> sbin[ 4] & sbin[ 5]
// spatial_cmp[11] --> sbin[ 6] & sbin[ 7]

// spatial_cmp[12] --> sbin[ 8] & sbin[ 9]
// spatial_cmp[13] --> sbin[10] & sbin[11]

// spatial_cmp[14] --> sbin[12] & sbin[13]
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_max_bin_val <= 0;
        s_max_bin_dis <= 0;
        s_max_bin_loc <= 0;
    end
    else if (current_state == STATE_IDLE) begin // reset after writing back to DRAM
        s_max_bin_val <= 0;
        s_max_bin_dis <= 0;
        s_max_bin_loc <= 0;
    end
    else begin
        case (current_calc_state)
            CALC_CONVEX,
            CALC_CONCAVE:   if (cnt_buffer_arr[23] == 235) begin
                s_max_bin_val <= spatial_bin_val[14];
                s_max_bin_dis <= spatial_bin_dis[14];
                s_max_bin_loc <= spatial_bin_loc[14];
            end
            // CALC_CONCAVE:   if (cnt_buffer_arr[23] == 235) begin
            //     s_max_bin_val <= spatial_bin_val[14];
            //     s_max_bin_dis <= spatial_bin_dis[14];
            //     s_max_bin_loc <= spatial_bin_loc[14];
            // end
            default: ;
        endcase
    end
end

generate
    assign  spatial_cmp[ 0] = max_bin_val[ 0] > max_bin_val[ 1];
    assign  spatial_cmp[ 1] = max_bin_val[ 2] > max_bin_val[ 3];
    assign  spatial_cmp[ 2] = max_bin_val[ 4] > max_bin_val[ 5];
    assign  spatial_cmp[ 3] = max_bin_val[ 6] > max_bin_val[ 7];
    assign  spatial_cmp[ 4] = max_bin_val[ 8] > max_bin_val[ 9];
    assign  spatial_cmp[ 5] = max_bin_val[10] > max_bin_val[11];
    assign  spatial_cmp[ 6] = max_bin_val[12] > max_bin_val[13];
    assign  spatial_cmp[ 7] = max_bin_val[14] > max_bin_val[15];
    assign  spatial_bin_val[ 0] = (spatial_cmp[ 0]) ? max_bin_val[ 0] : max_bin_val[ 1];
    assign  spatial_bin_val[ 1] = (spatial_cmp[ 1]) ? max_bin_val[ 2] : max_bin_val[ 3];
    assign  spatial_bin_val[ 2] = (spatial_cmp[ 2]) ? max_bin_val[ 4] : max_bin_val[ 5];
    assign  spatial_bin_val[ 3] = (spatial_cmp[ 3]) ? max_bin_val[ 6] : max_bin_val[ 7];
    assign  spatial_bin_val[ 4] = (spatial_cmp[ 4]) ? max_bin_val[ 8] : max_bin_val[ 9];
    assign  spatial_bin_val[ 5] = (spatial_cmp[ 5]) ? max_bin_val[10] : max_bin_val[11];
    assign  spatial_bin_val[ 6] = (spatial_cmp[ 6]) ? max_bin_val[12] : max_bin_val[13];
    assign  spatial_bin_val[ 7] = (spatial_cmp[ 7]) ? max_bin_val[14] : max_bin_val[15];
    assign  spatial_bin_dis[ 0] = (spatial_cmp[ 0]) ? max_bin_dis[ 0] : max_bin_dis[ 1];
    assign  spatial_bin_dis[ 1] = (spatial_cmp[ 1]) ? max_bin_dis[ 2] : max_bin_dis[ 3];
    assign  spatial_bin_dis[ 2] = (spatial_cmp[ 2]) ? max_bin_dis[ 4] : max_bin_dis[ 5];
    assign  spatial_bin_dis[ 3] = (spatial_cmp[ 3]) ? max_bin_dis[ 6] : max_bin_dis[ 7];
    assign  spatial_bin_dis[ 4] = (spatial_cmp[ 4]) ? max_bin_dis[ 8] : max_bin_dis[ 9];
    assign  spatial_bin_dis[ 5] = (spatial_cmp[ 5]) ? max_bin_dis[10] : max_bin_dis[11];
    assign  spatial_bin_dis[ 6] = (spatial_cmp[ 6]) ? max_bin_dis[12] : max_bin_dis[13];
    assign  spatial_bin_dis[ 7] = (spatial_cmp[ 7]) ? max_bin_dis[14] : max_bin_dis[15];
    assign  spatial_bin_loc[ 0] = (spatial_cmp[ 0]) ?  0 :  1;
    assign  spatial_bin_loc[ 1] = (spatial_cmp[ 1]) ?  2 :  3;
    assign  spatial_bin_loc[ 2] = (spatial_cmp[ 2]) ?  4 :  5;
    assign  spatial_bin_loc[ 3] = (spatial_cmp[ 3]) ?  6 :  7;
    assign  spatial_bin_loc[ 4] = (spatial_cmp[ 4]) ?  8 :  9;
    assign  spatial_bin_loc[ 5] = (spatial_cmp[ 5]) ? 10 : 11;
    assign  spatial_bin_loc[ 6] = (spatial_cmp[ 6]) ? 12 : 13;
    assign  spatial_bin_loc[ 7] = (spatial_cmp[ 7]) ? 14 : 15;

    assign  spatial_cmp[ 8] = spatial_bin_val[ 0] > spatial_bin_val[ 1];
    assign  spatial_cmp[ 9] = spatial_bin_val[ 2] > spatial_bin_val[ 3];
    assign  spatial_cmp[10] = spatial_bin_val[ 4] > spatial_bin_val[ 5];
    assign  spatial_cmp[11] = spatial_bin_val[ 6] > spatial_bin_val[ 7];
    assign  spatial_bin_val[ 8] = (spatial_cmp[ 8]) ? spatial_bin_val[ 0] : spatial_bin_val[ 1];
    assign  spatial_bin_val[ 9] = (spatial_cmp[ 9]) ? spatial_bin_val[ 2] : spatial_bin_val[ 3];
    assign  spatial_bin_val[10] = (spatial_cmp[10]) ? spatial_bin_val[ 4] : spatial_bin_val[ 5];
    assign  spatial_bin_val[11] = (spatial_cmp[11]) ? spatial_bin_val[ 6] : spatial_bin_val[ 7];
    assign  spatial_bin_dis[ 8] = (spatial_cmp[ 8]) ? spatial_bin_dis[ 0] : spatial_bin_dis[ 1];
    assign  spatial_bin_dis[ 9] = (spatial_cmp[ 9]) ? spatial_bin_dis[ 2] : spatial_bin_dis[ 3];
    assign  spatial_bin_dis[10] = (spatial_cmp[10]) ? spatial_bin_dis[ 4] : spatial_bin_dis[ 5];
    assign  spatial_bin_dis[11] = (spatial_cmp[11]) ? spatial_bin_dis[ 6] : spatial_bin_dis[ 7];
    assign  spatial_bin_loc[ 8] = (spatial_cmp[ 8]) ? spatial_bin_loc[ 0] : spatial_bin_loc[ 1];
    assign  spatial_bin_loc[ 9] = (spatial_cmp[ 9]) ? spatial_bin_loc[ 2] : spatial_bin_loc[ 3];
    assign  spatial_bin_loc[10] = (spatial_cmp[10]) ? spatial_bin_loc[ 4] : spatial_bin_loc[ 5];
    assign  spatial_bin_loc[11] = (spatial_cmp[11]) ? spatial_bin_loc[ 6] : spatial_bin_loc[ 7];

    assign  spatial_cmp[12] = spatial_bin_val[ 8] > spatial_bin_val[ 9];
    assign  spatial_cmp[13] = spatial_bin_val[10] > spatial_bin_val[11];
    assign  spatial_cmp[14] = spatial_bin_val[12] > spatial_bin_val[13];
    assign  spatial_bin_val[12] = (spatial_cmp[12]) ? spatial_bin_val[ 8] : spatial_bin_val[ 9];
    assign  spatial_bin_val[13] = (spatial_cmp[13]) ? spatial_bin_val[10] : spatial_bin_val[11];
    assign  spatial_bin_val[14] = (spatial_cmp[14]) ? spatial_bin_val[12] : spatial_bin_val[13];
    assign  spatial_bin_dis[12] = (spatial_cmp[12]) ? spatial_bin_dis[ 8] : spatial_bin_dis[ 9];
    assign  spatial_bin_dis[13] = (spatial_cmp[13]) ? spatial_bin_dis[10] : spatial_bin_dis[11];
    assign  spatial_bin_dis[14] = (spatial_cmp[14]) ? spatial_bin_dis[12] : spatial_bin_dis[13];
    assign  spatial_bin_loc[12] = (spatial_cmp[12]) ? spatial_bin_loc[ 8] : spatial_bin_loc[ 9];
    assign  spatial_bin_loc[13] = (spatial_cmp[13]) ? spatial_bin_loc[10] : spatial_bin_loc[11];
    assign  spatial_bin_loc[14] = (spatial_cmp[14]) ? spatial_bin_loc[12] : spatial_bin_loc[13];
endgenerate

// Peak estimation using adjusted bins
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        predict_peak_val <= 0;
        predict_peak_dis <= 0;
        predict_peak_loc <= 0;
        predict_type <=     0;
    end
    else if (current_state == STATE_IDLE) begin // reset after writing back to DRAM
        predict_peak_val <= 0;
        predict_peak_dis <= 0;
        predict_peak_loc <= 0;
        predict_type <=     0;
    end
    else if ((current_calc_state == CALC_CONCAVE) && (cnt_buffer_arr[24] == 235) && in_calc_buffer_arr[24]) begin
        predict_peak_val <= s_max_bin_val;
        predict_peak_dis <= s_max_bin_dis;
        predict_peak_loc <= s_max_bin_loc;
        predict_type <=     3;
    end
    else if ((current_calc_state == CALC_CONVEX) && (cnt_buffer_arr[24] == 235) && in_calc_buffer_arr[24]) begin
        if (s_max_bin_val >= predict_peak_val) begin
            predict_peak_val <= s_max_bin_val;
            predict_peak_dis <= s_max_bin_dis;
            predict_peak_loc <= s_max_bin_loc;
            predict_type <=     2;
        end
    end
end
endmodule

// module DW02_sum_inst(
// 	// Input signals
//     inst_INPUT,
// 	// Output signals
// 	SUM_inst
// );
// //==================PARAMETER=====================//
// // num_inputs, input_width
// parameter num_inputs =   8;
// parameter input_width = 10;
// //=========INPUT AND OUTPUT DECLARATION==============//
// input   [num_inputs*input_width-1:0]    inst_INPUT;
// output  [           input_width-1:0]    SUM_inst;
// //==================Design===================//

// DW02_sum # (num_inputs, input_width) SUM_VEC(   
//     .INPUT(inst_INPUT),
//     .SUM(SUM_inst)
// );

// // synopsys dc_script_begin
// // set_implementation pparch SUM_VEC
// // synopsys dc_script_end
// endmodule
