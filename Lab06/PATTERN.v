//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : PATTERN.v
//   Module Name : PATTERN
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`ifdef RTL_TOP
    `define CYCLE_TIME 40.0
`endif

`ifdef GATE_TOP
    `define CYCLE_TIME 40.0
`endif

module PATTERN (
    // Output signals
    clk, rst_n, in_valid,
    in_p, in_q, in_e, in_c,
    // Input signals
    out_valid, out_m
);

// ===============================================================
// Parameter & Integer Declaration
// ===============================================================
// real CYCLE = `CYCLE_TIME;

integer a, i;
integer input_file;
integer curr_pat,   total_pat;
integer calc_cycle, total_calc_cycle, output_cycle, gap;

integer p_val, q_val, e_val;
integer m_list[7:0];
integer c_list[7:0];

// ===============================================================
// Input & Output Declaration
// ===============================================================
output reg clk, rst_n, in_valid;
output reg [3:0] in_p, in_q;
output reg [7:0] in_e, in_c;
input out_valid;
input [7:0] out_m;

//================================================================
// Wire & Reg Declaration
//================================================================

//================================================================
// Clock
//================================================================
initial clk = 0;
always	#(`CYCLE_TIME/2.0) clk = ~clk;

//================================================================
// Initial
//================================================================
initial begin
	input_file  = $fopen("../00_TESTBED/input.txt","r");
	a = $fscanf(input_file, "%d", total_pat);

    rst_n = 1'b1;
	in_valid = 1'b0;
	in_p = 4'bx;
	in_q = 4'bx;
	in_e = 8'bx;
	in_c = 8'bx;

    force clk = 0;
    reset_task;
    @(negedge clk);

    total_calc_cycle = 0;
    for (curr_pat=0; curr_pat<total_pat; curr_pat=curr_pat+1) begin
        input_data;
        check_process;
        $display("PASS PATTERN NO.%4d, Cycles: %4d", curr_pat , calc_cycle); // TBD could be more accurate
    end
    YOU_PASS_task;
end

always @(*) begin
	if ((in_valid===1) && (out_valid===1)) begin
		$display("---------------------------------------------");
		$display("               SPEC 11 IS FAIL!              ");
		$display("---------------------------------------------");
        $display("out_valid should not be raised when in_valid is high.");
		$display($time);
		$finish;
	end
end

always @(negedge clk) begin
	if ((out_m!==0) && (out_valid===0)) begin
        invalid_output_reset;
	end
end

// always @(*) begin // TBD fail at gate level since out_m signal is unknown. The condition is too strict
// 	if ((out_m!==0) && (out_valid===0)) begin
//         invalid_output_reset;
// 	end
// end

// SPEC  3  (Done)
// SPEC  7  (Done)
// SPEC 11  (Done) 
// SPEC 12  (Done)
// SEPC 15  (Done)
// SPEC 16  (Done)

//================================================================
// TASK
//================================================================
task check_process; begin
	calc_cycle = 0;    
    while (!out_valid) begin
        if (calc_cycle == 10000) begin
            $display("---------------------------------------------");
            $display("               SPEC 3 IS FAIL!               ");
            $display("---------------------------------------------");
            $display("The execution latency is limited in 10,000 cycles.");
			$display("The latency is the clock cycles between the falling edge of the last cycle of in_valid and the rising edge of the out_valid.");
            $display($time);
            $finish;
        end
		calc_cycle = calc_cycle + 1;
        @(negedge clk);
    end

    for (i=0;i<8;i=i+1) begin
        if (!out_valid) invalid_output_signal; // less than 8 cycles
        if (out_m !== m_list[i]) begin
            $display("---------------------------------------------");
            $display("               SPEC 15 IS FAIL!              ");
            $display("---------------------------------------------");
            $display("The out_m should be correct when out_valid is high.");
            $display("The %dth answer is %d rather than %d", i+1, m_list[i], out_m);
            $display($time);
            $finish;
        end
        @(negedge clk);
    end
    if (out_valid) invalid_output_signal; // more than 8 cycle
	
end endtask

task invalid_output_signal; begin
	$display("---------------------------------------------");
	$display("               SPEC 12 IS FAIL!              ");
	$display("---------------------------------------------");
	$display("The out_valid is limited to be high for only 8 cycles when the output value is valid.");
	$display($time);
	$finish;
end
endtask

task invalid_output_reset; begin
    $display("---------------------------------------------");
    $display("               SPEC 16 IS FAIL!              ");
    $display("---------------------------------------------");
    $display("The out_m should be reset after your out_valid is pulled down.");
    $display("out_valid: %b",out_valid);
    $display("out_m: %d",out_m);
    $display($time);
    $finish;
end
endtask

task input_data; begin
    gap = $urandom_range(2,4);
    repeat(gap) @(negedge clk);
	// read input pattern in order from file
	a = $fscanf(input_file, "%d", p_val);
	a = $fscanf(input_file, "%d", q_val);
	a = $fscanf(input_file, "%d", e_val);
    for (i=0;i<8;i=i+1) a = $fscanf(input_file, "%d", c_list[i]);
    for (i=0;i<8;i=i+1) a = $fscanf(input_file, "%d", m_list[i]);

    in_valid = 1'b1;
    in_p = p_val;
    in_q = q_val;
    in_e = e_val;
    in_c = c_list[0];
    @(negedge clk);

    for (i=1;i<8;i=i+1) begin
        in_p = 4'bx;
        in_q = 4'bx;
        in_e = 8'bx;
        in_c = c_list[i];
        @(negedge clk);
    end

	in_valid = 1'b0;
    in_p = 4'bx;
    in_q = 4'bx;
    in_e = 8'bx;
    in_c = 8'bx;

end endtask

task reset_task; begin
    #(15) rst_n = 0;
    #(10);
    if ((out_valid !== 0) || (out_m !== 0))  begin
        $display("---------------------------------------------");
        $display("               SPEC 7 IS FAIL!               ");
        $display("---------------------------------------------");
        $display("The reset signal (rst_n) would be given only once at the beginning of simulation.");
        $display("All output signals should be reset after the reset signal is asserted.");
        $display("out_valid %b", out_valid);
        $display("out_m %b", out_m);
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
    $display ("                                        Your execution cycles   = %5d cycles                                          ", calc_cycle);
    $display ("                                        Your clock period       = %.1f ns                                             ", `CYCLE_TIME);
    $display ("                                        Total latency           = %.1f ns                                             ", calc_cycle*`CYCLE_TIME );
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $finish;    
end endtask


endmodule