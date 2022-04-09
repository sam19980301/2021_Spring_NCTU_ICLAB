`ifdef RTL
	`timescale 1ns/1fs
	`include "NN.v"  
	`define CYCLE_TIME 21.0
`endif
`ifdef GATE
	`timescale 1ns/1fs
	`include "NN_SYN.v"
	`define CYCLE_TIME 21.0
`endif



module PATTERN(
	// Output signals
	clk,
	rst_n,
	in_valid_i,
	in_valid_k,
	in_valid_o,
	Image1,
	Image2,
	Image3,
	Kernel1,
	Kernel2,
	Kernel3,
	Opt,
	// Input signals
	out_valid,
	out
);

// ===============================================================
// Parameters & Integer Declaration
// ===============================================================
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 1;

integer curr_pat, total_pat;
integer calc_cycle, output_cycle;
integer input_file, a;
integer i;
real abs_diff;

//================================================================
// Input & Output Declaration
//================================================================
output reg clk, rst_n, in_valid_i, in_valid_k, in_valid_o;
output reg [inst_sig_width+inst_exp_width:0] Kernel1, Kernel2, Kernel3;
output reg [inst_sig_width+inst_exp_width:0] Image1, Image2 ,Image3;
output reg [1:0] Opt;
input	out_valid;
input	[inst_sig_width+inst_exp_width:0] out;

// ===============================================================
// Wire & Reg Declaration
// ===============================================================

reg [1:0] Opt_val;
reg [inst_sig_width+inst_exp_width:0] Kernel1_arr[35:0], Kernel2_arr[35:0], Kernel3_arr[35:0];
reg [inst_sig_width+inst_exp_width:0] Image1_arr[15:0], Image2_arr[15:0], Image3_arr[15:0];
reg [inst_sig_width+inst_exp_width:0] gt_answer[63:0];

reg [inst_sig_width+inst_exp_width:0] addsub_in_a_m, addsub_in_b_m;
wire [inst_sig_width+inst_exp_width:0] addsub_out_m;
wire [inst_sig_width+inst_exp_width:0] cmp_in_a;
wire agtb, aeqb;


//================================================================
// clock
//================================================================
always	#(`CYCLE_TIME/2.0) clk = ~clk;
initial	clk = 0;


// ===============================================================
// Initial
// ===============================================================
initial begin
	input_file  = $fopen("../00_TESTBED/input.txt","r");
	a = $fscanf(input_file, "%d", total_pat);

    rst_n = 1'b1;
	in_valid_i = 1'b0;
	in_valid_k = 1'b0;
	in_valid_o = 1'b0;
	Image1 = 32'bx;
	Image2 = 32'bx;
	Image3 = 32'bx;
	Kernel1 = 32'bx;
	Kernel2 = 32'bx;
	Kernel3 = 32'bx;
	Opt = 2'bx;

    force clk = 0;
    reset_task;
    @(negedge clk);

    for (curr_pat=0; curr_pat<total_pat; curr_pat=curr_pat+1) begin
        input_data;
        check_process;
        $display("PASS PATTERN NO.%4d, Cycles: %4d", curr_pat , calc_cycle);
    end
	YOU_PASS_task;
    $finish;
end

always @(*) begin
	if ((out !== 0) && (out_valid === 0)) begin
		$display("---------------------------------------------");
		$display("               SPEC 5 IS FAIL!               ");
		$display("---------------------------------------------");
		$display("The out should be reset after your out_valid is pulled down.");
		$display("The out is %032f / %032b in float / binary represenattion",out,out);
		$display($time);
		$finish;
	end
end


// SPEC 2
// SPEC 4
// SPEC 5
// SPEC 6

//================================================================
// PATTERN
//================================================================

task check_process; begin
	calc_cycle = 0;    
    while (!out_valid) begin // if allowed
        if (calc_cycle == 450-1) begin
            $display("---------------------------------------------");
            $display("               SPEC 6 IS FAIL!               ");
            $display("---------------------------------------------");
            $display("The execution latency is limited in 450 cycles.");
			$display("The latency is the clock cycles between the falling edge of the in_valid_k and the rising edge of the first out_valid.");
            $display($time);
            $finish;
        end
		calc_cycle = calc_cycle + 1;
        @(negedge clk);
    end

    output_cycle = 0;
	while (out_valid) begin
		if (output_cycle > 64) invalid_output_signal_length; // more than 64 cycles

		addsub_in_a_m = gt_answer[output_cycle];
		addsub_in_b_m = out;
		// if (agtb && (gt_answer[output_cycle] !== out)) begin
		for (i=0;i<32;i=i+1) begin
			if (out[i]===1'bx) begin
				invalid_output_signal_value;
			end
		end
		if (agtb) begin
			invalid_output_signal_value;
		end
		output_cycle = output_cycle + 1;
		@(negedge clk);
	end
	if (output_cycle != 64) invalid_output_signal_length; // less than 64 cycles
end endtask

task invalid_output_signal_value; begin
	$display("---------------------------------------------");
	$display("               SPEC 2 IS FAIL!               ");
	$display("---------------------------------------------");
	$display("You have to check an error under 0.009 for the result after converting to float number.");
	$display("The answer is %32b in float / binary represenattion",addsub_in_a_m);
	$display("The    out is %32b in float / binary represenattion",out);
	$display($time);
	$display(output_cycle);
	$finish;
end
endtask 

task invalid_output_signal_length; begin
	$display("---------------------------------------------");
	$display("               SPEC 0.5 IS FAIL!               ");
	$display("---------------------------------------------");
	$display("The output signal out must be delivered for 64 cycles.");
	$display($time);
	$finish;
end
endtask


task input_data; begin
    repeat(5) @(negedge clk);
	// read input pattern in order from file
	a = $fscanf(input_file, "%b", Opt_val);
	for (i=0;i<16;i=i+1) a = $fscanf(input_file, "%b", Image1_arr[i]);
	for (i=0;i<16;i=i+1) a = $fscanf(input_file, "%b", Image2_arr[i]);
	for (i=0;i<16;i=i+1) a = $fscanf(input_file, "%b", Image3_arr[i]);
	for (i=0;i<36;i=i+1) a = $fscanf(input_file, "%b", Kernel1_arr[i]);
	for (i=0;i<36;i=i+1) a = $fscanf(input_file, "%b", Kernel2_arr[i]);
	for (i=0;i<36;i=i+1) a = $fscanf(input_file, "%b", Kernel3_arr[i]);
	for (i=0;i<64;i=i+1) a = $fscanf(input_file, "%b", gt_answer[i]);

    in_valid_o = 1'b1;
	Opt = Opt_val;
	@(negedge clk);
	in_valid_o = 1'b0;
	Opt = 1'bx;
	repeat(2) @(negedge clk);

    in_valid_i = 1'b1;
	for (i=0;i<16;i=i+1) begin
		Image1 = Image1_arr[i];
		Image2 = Image2_arr[i];
		Image3 = Image3_arr[i];
		@(negedge clk);
	end
	in_valid_i = 1'b0;
	Image1 = 32'bx;
	Image2 = 32'bx;
	Image3 = 32'bx;
	repeat(2) @(negedge clk);

    in_valid_k = 1'b1;
	for (i=0;i<36;i=i+1) begin
		Kernel1 = Kernel1_arr[i];
		Kernel2 = Kernel2_arr[i];
		Kernel3 = Kernel3_arr[i];
		@(negedge clk);
	end
	in_valid_k = 1'b0;
	Kernel1 = 32'bx;
	Kernel2 = 32'bx;
	Kernel3 = 32'bx;

end endtask


task reset_task; begin
    #(15) rst_n = 0;
    #(10);
    if ((out_valid !== 0) || (out !== 0))  begin
        $display("---------------------------------------------");
        $display("               SPEC 4 IS FAIL!               ");
        $display("---------------------------------------------");
        $display("The reset signal (rst_n) would be given only once at the beginning of simulation.");
        $display("All output signals should be reset after the reset signal is asserted.");
        $display("i.e. Output signals is not reset.");
        $display("out_valid %01b", out_valid);
        $display("out %03b", out);
        $display($time);
        repeat(5)@(negedge clk);
        $finish;
    end
    #(10); rst_n = 1;
    #(3.0); release clk;
end endtask

task YOU_PASS_task;begin
$display ("----------------------------------------------------------------------------------------------------------------------");
$display ("                                                  Congratulations!                                                    ");
$display ("                                           You have passed all patterns!                                              ");
$display ("                                                                                                                      ");
$display ("                                        Your execution cycles   = %5d cycles                                          ", calc_cycle);
$display ("                                        Your clock period       = %.1f ns                                             ", `CYCLE_TIME);
$display ("                                        Total latency           = %.1f ns                                             ", calc_cycle*`CYCLE_TIME );
$display ("----------------------------------------------------------------------------------------------------------------------");
$finish;    
end endtask

DW_fp_addsub #(inst_sig_width, inst_exp_width, inst_ieee_compliance) SUB(
	.a(addsub_in_a_m),
	.b(addsub_in_b_m),
	.rnd(3'b000),
	.op(1'b1),
	.z(addsub_out_m), // gt_answer - modeul_answer
	.status()
);

assign cmp_in_a = {1'b0,addsub_out_m[30:0]}; // abs_diff

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance) MAX(
	.a(cmp_in_a),
	.b(32'h3a6bedfa), // 0.09:3c1374bc, 0.009:3a6bedfa
	.zctr(),
	.aeqb(),
	.altb(),
	.agtb(agtb),
	.unordered(),
	.z0(),
	.z1(),
	.status0(),
	.status1()
);

endmodule