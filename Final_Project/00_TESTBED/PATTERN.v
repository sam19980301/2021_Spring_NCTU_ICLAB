`include "../00_TESTBED/pseudo_DRAM.v"

`ifdef RTL
    `define CYCLE_TIME 5.5
`endif
`ifdef GATE
    `define CYCLE_TIME 5.5
`endif
`ifdef POST
    `define CYCLE_TIME 5.4
`endif

`define MODE 0
// Default (0): Normal mode
// 1:           Verbose mode    Showing correctness of  bin counting
// 2:           Strict mode     Stirctly checking the distance prediction

`define PAT_TYPE 7
//              Spatial Correlation of Pattern      Corner cases        # Pattern
// 0            Independent only (type0)                                  32
// 1            Group only (type1)                                       100
// 2            Convex only (type2)                                      100
// 3            Concave only (type3)                                     100
// 4            Convex or Concave only (type3)                           100
// 5            Independent or Group only (type01)  All corner cases     132
// 6            Convex or Concave only (type3)      All corner cases     100
// 7            *                                                        132
// 8            *                                                       1032

`define PAT_NUM 0
// Manually Set Pattern Number (Default 0)

module PATTERN #(parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32)(
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
    awid_s_inf,
    awaddr_s_inf,
    awsize_s_inf,
    awburst_s_inf,
    awlen_s_inf,
    awvalid_s_inf,
    awready_s_inf,

    wdata_s_inf,
    wlast_s_inf,
    wvalid_s_inf,
    wready_s_inf,

    bid_s_inf,
    bresp_s_inf,
    bvalid_s_inf,
    bready_s_inf,

    arid_s_inf,
    araddr_s_inf,
    arlen_s_inf,
    arsize_s_inf,
    arburst_s_inf,
    arvalid_s_inf,

    arready_s_inf, 
    rid_s_inf,
    rdata_s_inf,
    rresp_s_inf,
    rlast_s_inf,
    rvalid_s_inf,
    rready_s_inf 
);

// ===============================================================
//                      Input / Output 
// ===============================================================

// << CHIP io port with system >>
output reg              clk, rst_n;
output reg              in_valid;
output reg              start;
output reg [15:0]       stop;     
output reg [1:0]        inputtype; 
output reg [4:0]        frame_id;
input                   busy;       

// << AXI Interface wire connecttion for pseudo DRAM read/write >>
// (1)     axi write address channel 
//         src master
input wire [ID_WIDTH-1:0]      awid_s_inf;
input wire [ADDR_WIDTH-1:0]  awaddr_s_inf;
input wire [2:0]             awsize_s_inf;
input wire [1:0]            awburst_s_inf;
input wire [7:0]              awlen_s_inf;
input wire                  awvalid_s_inf;
//         src slave
output wire                 awready_s_inf;
// -----------------------------

// (2)    axi write data channel 
//         src master
input wire [DATA_WIDTH-1:0]   wdata_s_inf;
input wire                    wlast_s_inf;
input wire                   wvalid_s_inf;
//         src slave
output wire                  wready_s_inf;

// (3)    axi write response channel 
//         src slave
output wire  [ID_WIDTH-1:0]     bid_s_inf;
output wire  [1:0]            bresp_s_inf;
output wire                  bvalid_s_inf;
//         src master 
input wire                   bready_s_inf;
// -----------------------------

// (4)    axi read address channel 
//         src master
input wire [ID_WIDTH-1:0]      arid_s_inf;
input wire [ADDR_WIDTH-1:0]  araddr_s_inf;
input wire [7:0]              arlen_s_inf;
input wire [2:0]             arsize_s_inf;
input wire [1:0]            arburst_s_inf;
input wire                  arvalid_s_inf;
//         src slave
output wire                 arready_s_inf;
// -----------------------------

// (5)    axi read data channel 
//         src slave
output wire [ID_WIDTH-1:0]      rid_s_inf;
output wire [DATA_WIDTH-1:0]  rdata_s_inf;
output wire [1:0]             rresp_s_inf;
output wire                   rlast_s_inf;
output wire                  rvalid_s_inf;
//         src master
input wire                   rready_s_inf;


// -------------------------//
//     DRAM Connection      //
//--------------------------//

pseudo_DRAM u_DRAM(
    .clk(clk),
    .rst_n(rst_n),

    .   awid_s_inf(   awid_s_inf),
    . awaddr_s_inf( awaddr_s_inf),
    . awsize_s_inf( awsize_s_inf),
    .awburst_s_inf(awburst_s_inf),
    .  awlen_s_inf(  awlen_s_inf),
    .awvalid_s_inf(awvalid_s_inf),
    .awready_s_inf(awready_s_inf),

    .  wdata_s_inf(  wdata_s_inf),
    .  wlast_s_inf(  wlast_s_inf),
    . wvalid_s_inf( wvalid_s_inf),
    . wready_s_inf( wready_s_inf),

    .    bid_s_inf(    bid_s_inf),
    .  bresp_s_inf(  bresp_s_inf),
    . bvalid_s_inf( bvalid_s_inf),
    . bready_s_inf( bready_s_inf),

    .   arid_s_inf(   arid_s_inf),
    . araddr_s_inf( araddr_s_inf),
    .  arlen_s_inf(  arlen_s_inf),
    . arsize_s_inf( arsize_s_inf),
    .arburst_s_inf(arburst_s_inf),
    .arvalid_s_inf(arvalid_s_inf),
    .arready_s_inf(arready_s_inf), 

    .    rid_s_inf(    rid_s_inf),
    .  rdata_s_inf(  rdata_s_inf),
    .  rresp_s_inf(  rresp_s_inf),
    .  rlast_s_inf(  rlast_s_inf),
    . rvalid_s_inf( rvalid_s_inf),
    . rready_s_inf( rready_s_inf) 
);

// ===============================================================
// Parameter & Integer Declaration
// ===============================================================
// meta variable
integer input_file;
integer a, i, j, k, idx;
integer pat, total_pat;
integer gap;
integer start_cnt;
integer calc_cycle, total_calc_cycle;
integer error;

// pattern variable
integer frame_id_val;
integer type_val;
integer stop_val;
integer golden_hist[ 15:0][255:0];

integer pat_correct;
integer pat_error;
integer type_count_arr          [3:0];
integer type_correct_count_arr  [3:0];
integer type_error_count_arr    [3:0];

//================================================================
// Wire & Reg Declaration
//================================================================
// reg [15:0] stop_reg;

//================================================================
// Clock
//================================================================
initial clk = 0;
always	#(`CYCLE_TIME/2.0) clk = ~clk;

//================================================================
// Initial
//================================================================
initial begin
    rst_n =          1'b1;
	in_valid =       1'b0;
	start =          1'bx;
	stop =          16'bx;
    inputtype =      2'bx;
    frame_id =       5'bx;

    force clk = 0;
    reset_task;
    @(negedge clk);

    for (i=0; i<4; i=i+1) begin
        type_count_arr[i] =         0;
        type_correct_count_arr[i] = 0;
        type_error_count_arr[i] =   0;
    end

    total_calc_cycle = 0;
    if (`PAT_TYPE == 0) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type0.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type0.dat", u_DRAM.DRAM_r);
    end
    else if (`PAT_TYPE == 1) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type1.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type1.dat", u_DRAM.DRAM_r);
    end
    else if (`PAT_TYPE == 2) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type2.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type2.dat", u_DRAM.DRAM_r);
    end
    else if (`PAT_TYPE == 3) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type3.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type3.dat", u_DRAM.DRAM_r);
    end
    else if (`PAT_TYPE == 4) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type4.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type4.dat", u_DRAM.DRAM_r);
    end
    else if (`PAT_TYPE == 5) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type5.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type5.dat", u_DRAM.DRAM_r);
    end
    else if (`PAT_TYPE == 6) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type6.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type6.dat", u_DRAM.DRAM_r);
    end
    else if (`PAT_TYPE == 7) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type7.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type7.dat", u_DRAM.DRAM_r);
    end
    else if (`PAT_TYPE == 8) begin
        input_file  = $fopen("../00_TESTBED/pattern_data/input_type8.txt","r");
        $readmemh("../00_TESTBED/pattern_data/dram_type8.dat", u_DRAM.DRAM_r);
    end
    else begin
        $display("Wrong Pattern Type: %d",`PAT_TYPE);
        $finish;
    end
    a = $fscanf(input_file, "%d", total_pat);
    if (`PAT_NUM != 0) total_pat = `PAT_NUM;
    for (pat=0; pat< total_pat; pat=pat+1) begin
        input_data;
        check_process;
        $display("\033[0;34mPASS TYPE_%1d PATTERN NO.%4d,\033[m \033[0;32m Cycles: %4d, Accuracy %2d / %2d, Error %4d\033[m",
                type_val, pat, calc_cycle,
                pat_correct, 16, pat_error
        );
    end
    YOU_PASS_task;
end

always @(negedge clk) begin // always(*) may be too strict
	if ((busy===1) && (in_valid===1)) begin
        $display("---------------------------------------------");
        $display("           SPEC Out7 IS FAIL!                ");
        $display("---------------------------------------------");
        $display("busy should not be raised when in_valid is high.");
        $display("The test pattern will check whether your data in DRAM is correct or not at the first clock negative edge after busy pulled low.");
        $display($time);
        $finish;
	end
end

// SPEC Out4    (Done)
// SPEC Out6    (Done)
// SEPC Out7    (Done)
// SPEC 5       (Done)

//================================================================
// Task
//================================================================
task check_process; begin
    // According to SPEC, an extra cycle of low-signal busy is allowed after in_valid pulls low
    @(negedge clk);

	calc_cycle = 0;
    while (busy === 1) begin
        if (calc_cycle == 1000000) begin // 10000
            $display("---------------------------------------------");
            $display("               SPEC 5 IS FAIL!               ");
            $display("---------------------------------------------");
            $display("busy signal cannot be continuous high for over 1,000,000 cycles");
            $display($time);
            $finish;
        end
		calc_cycle = calc_cycle + 1;
        @(negedge clk);
    end
    total_calc_cycle = total_calc_cycle + calc_cycle;

    check_DRAM;
	
end endtask

// check single frame of DRAM
task check_DRAM; begin
    for (i=0; i<256; i=i+1) begin
        for (j=0; j<16; j=j+1) begin
            a = $fscanf(input_file, "%d", golden_hist[j][i]);
        end
    end
    pat_correct = 0;
    pat_error = 0;
    for (i=0; i<16; i=i+1) begin // i th histogram
        for (j=0; j<256; j=j+1) begin // j th bin or distance
            idx = (frame_id_val+16)*4096 + i*256 + j;
            if (j != 255) begin // checking histogram
                if (u_DRAM.DRAM_r[idx] !== golden_hist[i][j]) begin
                    $display("---------------------------------------------");
                    $display("            SPEC Out4 IS FAIL!               ");
                    $display("---------------------------------------------");
                    $display("After busy is pulled low, pattern will check the correctness of that frame value inside DRAM.");
                    $display("The value in address %h should be %d rather than %d",idx, golden_hist[i][j], u_DRAM.DRAM_r[idx]);
                    $display($time);
                    $finish;
                end
                else if (`MODE == 1) begin
                    $display("The value in address %h is the correct answer %d.", idx, u_DRAM.DRAM_r[idx]);
                end
            end
            else begin // checking distance
                error = u_DRAM.DRAM_r[idx] - golden_hist[i][j];
                error = (error > 0) ? error : -error;

                type_count_arr[type_val] =              type_count_arr[type_val] + 1;
                pat_error =                             pat_error + error;
                type_error_count_arr[type_val] =        type_error_count_arr[type_val] + error;
                
                if (error <= 3) begin
                    type_correct_count_arr[type_val] =  type_correct_count_arr[type_val] + 1;
                    pat_correct =                       pat_correct + 1;
                end
                else if (`MODE == 2) begin
                    $display("Wrong distance drediction.");
                    $display("Prediction Distances");
                    for (k=0; k<4; k=k+1) begin
                        $display("%3d\t%3d\t%3d\t%3d",
                        u_DRAM.DRAM_r[(frame_id_val+16)*4096 + (k*4+0)*256 + 255],
                        u_DRAM.DRAM_r[(frame_id_val+16)*4096 + (k*4+1)*256 + 255],
                        u_DRAM.DRAM_r[(frame_id_val+16)*4096 + (k*4+2)*256 + 255],
                        u_DRAM.DRAM_r[(frame_id_val+16)*4096 + (k*4+3)*256 + 255] 
                        );
                    end
                    $display("Golden Distance");
                    for (k=0; k<4; k=k+1) begin
                        $display("%3d\t%3d\t%3d\t%3d",
                        golden_hist[k*4+0][255],
                        golden_hist[k*4+1][255],
                        golden_hist[k*4+2][255],
                        golden_hist[k*4+3][255]
                        );
                    end
                    $finish;
                end
            end       
        end
    end
end endtask

task input_data; begin
    a = $fscanf(input_file, "%d", type_val);
    a = $fscanf(input_file, "%d", frame_id_val);

    gap = $urandom_range(3,10);
    repeat(gap) @(negedge clk);

    in_valid =  1'b1;
    if (type_val != 0) begin
        start_cnt = (type_val == 1) ? 4 : 7;
        for (i=0;i<start_cnt;i=i+1) begin
            gap = $urandom_range(3,10);
            for (j=0;j<gap;j=j+1) begin
                if ((i==0) && (j==0)) begin
                    start =     1'b0;
                    stop =      1'b0;
                    inputtype = type_val;
                    frame_id =  frame_id_val;
                end
                else begin
                    start =     1'b0;
                    stop =      1'b0;
                    inputtype = 2'bx;
                    frame_id =  5'bx;
                end
                @(negedge clk);
            end
            for (j=0;j<255;j=j+1) begin
                a = $fscanf(input_file, "%b", stop_val); // $urandom_range(0,65535);

                start =     1'b1;
                stop =      stop_val;
                inputtype = 2'bx;
                frame_id =  5'bx;
                @(negedge clk);
            end
        end
    end
    else begin
        start =     1'bx;
        stop =      1'bx;
        inputtype = type_val;
        frame_id =  frame_id_val;
        @(negedge clk);
    end

    in_valid =  1'b0;
    start =     1'bx;
    stop =      1'bx;
    inputtype = 2'bx;
    frame_id =  5'bx;

    @(negedge clk);
end endtask

task reset_task; begin
    #(15) rst_n = 0;
    #(10);
    if ((busy !== 0))  begin
        $display("---------------------------------------------");
        $display("            SPEC Out6 IS FAIL!               ");
        $display("---------------------------------------------");
        $display("busy should be low after initial reset.");
        $display("busy %b", busy);
        $display($time);
        $finish;
    end
    #(10); rst_n = 1;
    #(3.0); release clk;
end endtask

task YOU_PASS_task; begin
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $display ("                                                 Accuracy Summary                                                     ");
    $display ("                                Type 0: %5d / %5d. Accuracy: %.4f. Total Error: %6d                                    ",type_correct_count_arr[0],type_count_arr[0],1.0 * type_correct_count_arr[0] / type_count_arr[0],type_error_count_arr[0]);
    $display ("                                Type 1: %5d / %5d. Accuracy: %.4f. Total Error: %6d                                    ",type_correct_count_arr[1],type_count_arr[1],1.0 * type_correct_count_arr[1] / type_count_arr[1],type_error_count_arr[1]);
    $display ("                                Type 2: %5d / %5d. Accuracy: %.4f. Total Error: %6d                                    ",type_correct_count_arr[2],type_count_arr[2],1.0 * type_correct_count_arr[2] / type_count_arr[2],type_error_count_arr[2]);
    $display ("                                Type 3: %5d / %5d. Accuracy: %.4f. Total Error: %6d                                    ",type_correct_count_arr[3],type_count_arr[3],1.0 * type_correct_count_arr[3] / type_count_arr[3],type_error_count_arr[3]);
    $display ("----------------------------------------------------------------------------------------------------------------------");
    
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $display ("                                                  Congratulations!                                                    ");
    $display ("                                           You have passed all patterns!                                              ");
    $display ("                                                                                                                      ");
    $display ("                                        Your execution cycles   = %5d cycles                                          ", total_calc_cycle);
    $display ("                                        Your clock period       = %.1f ns                                             ", `CYCLE_TIME);
    $display ("                                        Total latency           = %.1f ns                                             ", total_calc_cycle*`CYCLE_TIME );
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $finish;
end endtask

endmodule

