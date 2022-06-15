`define CYCLE_TIME 12

// enable clock gating or not
`define CG_EN 1

module PATTERN(
	// Output signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	in_data,
	op,
	// Output signals
	out_valid,
	out_data
);

// ===============================================================
// Parameters & Integer Declaration
// ===============================================================
integer a, i;
integer input_file;
integer curr_pat,total_pat;
integer calc_cycle, total_calc_cycle, output_cycle, gap;

integer input_array[63:0];
integer action_array[14:0];
integer answer_array[15:0];

//================================================================
// Input & Output Declaration
//================================================================
output reg clk;
output reg rst_n;
output reg cg_en;
output reg in_valid;
output reg signed [6:0] in_data;
output reg [3:0] op;

input out_valid;
input signed [6:0] out_data;

// ===============================================================
// Wire & Reg Declaration
// ===============================================================

//================================================================
// Clock
//================================================================
always	#(`CYCLE_TIME/2.0) clk = ~clk;
initial	clk = 0;

// ===============================================================
// Initial
// ===============================================================

initial begin
	input_file  = $fopen("../00_TESTBED/input.txt","r");
	a = $fscanf(input_file, "%d", total_pat);

    rst_n = 	'b1;
	cg_en = 	`CG_EN;
	in_valid = 	'b0;
	in_data = 	'bx;
	op = 		'bx;

    force clk = 0;
    reset_task;
    @(negedge clk);

    total_calc_cycle = 0;
    for (curr_pat=0; curr_pat<total_pat; curr_pat=curr_pat+1) begin
        input_data;
        check_process;
        $display("PASS PATTERN NO.%4d, Cycles: %4d", curr_pat , calc_cycle);
    end
    YOU_PASS_task;
end

always @(*) begin	// TBD or posedge / negedge clk to be less restrict
	if ((in_valid === 1) && (out_valid === 1)) begin
		$display("---------------------------------------------");
		$display("              SPEC 17 IS FAIL!               ");
		$display("---------------------------------------------");
        $display("The out_valid cannot overlap with in_valid.");
        $display("in_valid %b", in_valid);
        $display("out_valid %b", out_valid);
		$display($time);
		$finish;
	end
end

// Output	(Done)
// SPEC  4	(Done)
// SPEC 16	(Done)
// SPEC 17	(Done)

//================================================================
// Task
//================================================================

task check_process; begin
	calc_cycle = 0;
    while (!out_valid) begin
        if (calc_cycle == 1000) begin
            $display("---------------------------------------------");
            $display("               SPEC 16 IS FAIL!              ");
            $display("---------------------------------------------");
            $display("The execution latency is limited in 1000 cycles.");
            $display($time);
            $finish;
        end
		calc_cycle = calc_cycle + 1;
		total_calc_cycle = total_calc_cycle + 1;
        @(negedge clk);
    end

    output_cycle = 0;
	while (out_valid) begin
		if (output_cycle >= 16) invalid_output_signal;	// out_valid be high too long
        if (out_data !== answer_array[output_cycle]) invalid_output_value;
		output_cycle = output_cycle + 1;
		@(negedge clk);
	end
	if (output_cycle != 16) invalid_output_signal;		// out_valid be high too short
end endtask

task invalid_output_signal; begin
	$display("---------------------------------------------");
	$display("            Output 0.1 IS FAIL!              ");
	$display("---------------------------------------------");
    $display("Output 0.1 Every output signal should be correct when out_valid is high.");
	$display("The cycles of output signal is wrong, %d / %d",output_cycle, 16);
	$display($time);
	$finish;
end
endtask

task invalid_output_value; begin
    $display("---------------------------------------------");
	$display("            Output 0.2 IS FAIL!              ");
    $display("---------------------------------------------");
    $display("Output 0.2 Every output signal should be correct when out_valid is high.");
    $display("out_value should be %d rather than %d",answer_array[output_cycle], out_data);
    $display($time);
    $finish;
end
endtask

task input_data; begin
	// read input pattern in order from file
	for (i=0; i<64; i=i+1)	a = $fscanf(input_file, "%d", input_array[i]);
	for (i=0; i<15; i=i+1)	a = $fscanf(input_file, "%d", action_array[i]);
	for (i=0; i<16; i=i+1)	a = $fscanf(input_file, "%d", answer_array[i]);

    gap = $urandom_range(2,5);
    repeat(gap) @(negedge clk);
    in_valid = 1'b1;
	for (i=0; i<64; i=i+1) begin
		in_data = 	input_array[i];
		op = 		(i<15) ? action_array[i] : 'bx;
		@(negedge clk);
	end
	in_valid =	'b0;
	in_data =	'bx;
	op = 		'bx;
    @(negedge clk);
end endtask

task reset_task; begin
    #(15) rst_n = 0;
    #(10);
    if ((out_valid !== 0) || (out_data !== 0))  begin
        $display("---------------------------------------------");
        $display("               SPEC 4 IS FAIL!               ");
        $display("---------------------------------------------");
        $display("All your output register should be set zero after reset.");
        $display("out_valid %b",	out_valid);
        $display("out_data %b", 	out_data);
        $display($time);
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
$display ("                                        Your execution cycles   = %5d cycles                                          ", total_calc_cycle);
$display ("                                        Your clock period       = %.1f ns                                             ", `CYCLE_TIME);
$display ("                                        Total latency           = %.1f ns                                             ", total_calc_cycle*`CYCLE_TIME );
$display ("----------------------------------------------------------------------------------------------------------------------");
$finish;
end endtask
endmodule
