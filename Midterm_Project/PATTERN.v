`ifdef RTL
    `define CYCLE_TIME 4.7
`endif
`ifdef GATE
    `define CYCLE_TIME 4.7
`endif

`include "../00_TESTBED/pseudo_DRAM.v"

module PATTERN #(parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32)(
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
output reg [1:0]        window; 
output reg              mode;
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
integer temp;

// pattern variable
integer window_val;
integer mode_val;
integer frame_id_val;
integer stop_val;
integer golden_hist[ 15:0][255:0];
// integer golden_dist[ 15:0];

//================================================================
// Wire & Reg Declaration
//================================================================
reg [15:0] stop_reg;

//================================================================
// Clock
//================================================================
initial clk = 0;
always	#(`CYCLE_TIME/2.0) clk = ~clk;

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

pseudo_DRAM u_DRAM_GOLDEN(
    .clk(clk),
    .rst_n(rst_n),

    .   awid_s_inf(),
    . awaddr_s_inf(),
    . awsize_s_inf(),
    .awburst_s_inf(),
    .  awlen_s_inf(),
    .awvalid_s_inf(),
    .awready_s_inf(),

    .  wdata_s_inf(),
    .  wlast_s_inf(),
    . wvalid_s_inf(),
    . wready_s_inf(),

    .    bid_s_inf(),
    .  bresp_s_inf(),
    . bvalid_s_inf(),
    . bready_s_inf(),

    .   arid_s_inf(),
    . araddr_s_inf(),
    .  arlen_s_inf(),
    . arsize_s_inf(),
    .arburst_s_inf(),
    .arvalid_s_inf(),
    .arready_s_inf(), 

    .    rid_s_inf(),
    .  rdata_s_inf(),
    .  rresp_s_inf(),
    .  rlast_s_inf(),
    . rvalid_s_inf(),
    . rready_s_inf() 
);

    // initialize DRAM: $readmemh("../00_TESTBED/dram.dat", u_DRAM.DRAM_r);
    // direct access DRAM: u_DRAM.DRAM_r[addr][7:0];

//================================================================
// Initial
//================================================================

initial begin
    input_file  = $fopen("../00_TESTBED/input.txt","r");
    $readmemh("../00_TESTBED/dram.dat", u_DRAM.DRAM_r);
    $readmemh("../00_TESTBED/golden_dram.dat", u_DRAM_GOLDEN.DRAM_r);
    a = $fscanf(input_file, "%d", total_pat);

    rst_n =      1'b1;
	in_valid =   1'b0;
	start =      1'bx;
	stop =      16'bx;
	window =     2'bx;
	mode =       1'bx;
    frame_id =   5'bx;

    force clk = 0;
    reset_task;
    @(negedge clk);

    total_calc_cycle = 0;
    for (pat=0; pat<total_pat; pat=pat+1) begin
        input_data;
        check_process;
        $display("PASS PATTERN NO.%4d, Cycles: %4d", pat , calc_cycle);
    end

    for (pat=0;pat<32;pat=pat+1) begin
        frame_id_val = pat;
        check_DRAM;
        $display("DOUBLE CHECK DRAM FRAME: %4d", pat);
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
// SEPC 3       (Done)

//================================================================
// task
//================================================================

task check_process; begin

    // According to SPEC, an extra cycle of low-signal busy is allowed after in_valid pulls low
    @(negedge clk);

	calc_cycle = 0;
    while (busy===1) begin
        if (calc_cycle == 1000000) begin // 10000
            $display("---------------------------------------------");
            $display("               SPEC 3 IS FAIL!               ");
            $display("---------------------------------------------");
            $display("The latency of your design in each pattern should not be larger than 1,000,000 cycles.");
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
    for (i=0;i<16;i=i+1) begin // i th histogram
        for (j=0;j<256;j=j+1) begin // j th bin or distance
            idx = (frame_id_val+16)*4096 + (i)*256 + (j)*1;
            if (u_DRAM.DRAM_r[idx] !== u_DRAM_GOLDEN.DRAM_r[idx]) begin
                invalid_DRAM_value;
            end
        end
    end
end endtask

task invalid_DRAM_value; begin
    $display("---------------------------------------------");
    $display("            SPEC Out4 IS FAIL!               ");
    $display("---------------------------------------------");
    $display("After busy is pulled low, pattern will check the correctness of that frame value inside DRAM.");
    $display("The value in address %h should be %d rather than %d",idx, u_DRAM_GOLDEN.DRAM_r[idx], u_DRAM.DRAM_r[idx]);
    $display($time);
    $finish;
end endtask

task input_data; begin
    a = $fscanf(input_file, "%d", window_val);      // $urandom_range(0,  3);
    a = $fscanf(input_file, "%d", mode_val);        // $urandom_range(0,  1);
    a = $fscanf(input_file, "%d", frame_id_val);    // $urandom_range(0, 31);

    gap = $urandom_range(3,10);
    repeat(gap) @(negedge clk);

    in_valid =  1'b1;
    if (mode_val==0) begin
        a = $fscanf(input_file, "%d", start_cnt);   // $urandom_range(4,255);
        for (i=0;i<start_cnt;i=i+1) begin
            gap = $urandom_range(3,10);
            for (j=0;j<gap;j=j+1) begin
                if ((i==0) && (j==0)) begin
                    start =     1'b0;
                    stop =      1'b0;
                    window =    window_val;
                    mode =      mode_val;
                    frame_id =  frame_id_val;
                end
                else begin
                    start =     1'b0;
                    stop =      1'b0;
                    window =    2'bx;
                    mode =      1'bx;
                    frame_id =  5'bx;
                end
                @(negedge clk);
            end
            for (j=0;j<255;j=j+1) begin
                a = $fscanf(input_file, "%b", stop_val); // $urandom_range(0,65535);

                start =     1'b1;
                stop =      stop_val;
                window =    2'bx;
                mode =      1'bx;
                frame_id =  5'bx;
                @(negedge clk);
            end
        end
    end
    else begin
        start =     1'bx;
        stop =      1'bx;
        window =    window_val;
        mode =      mode_val;
        frame_id =  frame_id_val;
        @(negedge clk);
    end

    in_valid =  1'b0;
    start =     1'bx;
    stop =      1'bx;
    window =    2'bx;
    mode =      1'bx;
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