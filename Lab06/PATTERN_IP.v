//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : PATTERN_IP.v
//   Module Name : PATTERN_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`ifdef RTL
    `define CYCLE_TIME 60.0
`endif

`ifdef GATE
    `define CYCLE_TIME 60.0
`endif

module PATTERN_IP #(parameter WIDTH = 3) (
    // Input signals
    IN_P, IN_Q, IN_E,
    // Output signals
    OUT_N, OUT_D
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
output reg [WIDTH-1:0]   IN_P, IN_Q;
output reg [WIDTH*2-1:0] IN_E;
input      [WIDTH*2-1:0] OUT_N, OUT_D;

// ===============================================================
// Parameter & Integer Declaration
// ===============================================================
integer a;
integer input_file;
integer curr_pat,total_pat;

integer p_val, q_val, e_val;

integer ans_n;
integer mod;
integer etf;

//================================================================
// Wire & Reg Declaration
//================================================================
reg clk;

//================================================================
// Clock
//================================================================
initial clk = 0;
always #(`CYCLE_TIME/2.0) clk = ~clk;

//================================================================
// Initial
//================================================================
initial begin
	input_file  = $fopen("../00_TESTBED/input_ip.txt","r");
	a = $fscanf(input_file, "%d", total_pat);

    IN_P = {{(WIDTH){1'bx}}};
    IN_Q = {{(WIDTH){1'bx}}};
    IN_E = {{(WIDTH){1'bx}}};
    for (curr_pat=0; curr_pat<total_pat; curr_pat=curr_pat+1) begin
        input_data;
        check_ans;
        repeat(3) @(negedge clk);
        $display("PASS PATTERN NO.%5d", curr_pat);
    end
    you_pass_task;
end

//================================================================
// TASK
//================================================================
task check_ans; begin
    etf = ((p_val-1) * (q_val-1));
    mod = (e_val * OUT_D) - (e_val * OUT_D / etf * etf);
    ans_n = p_val * q_val;
    if ((mod !== 1) || (ans_n !== OUT_N)) begin
        $display("---------------------------------------------");
        $display("               SPEC 0 IS FAIL!               ");
        $display("---------------------------------------------");
        $display("The answer is wrong.");
        $display("IN_P %d",p_val);
        $display("IN_Q %d",q_val);
        $display("IN_E %d",e_val);
        $display("OUT_N should be %d rather than ", ans_n, OUT_N);
        $display("OUT_D %d",OUT_D);
        $display($time);
        $finish;
    end
end endtask

task input_data; begin
	// read input pattern in order from file
    a = $fscanf(input_file, "%d", p_val); // TBD or split it into steps
    a = $fscanf(input_file, "%d", q_val);
    a = $fscanf(input_file, "%d", e_val);
    IN_P = p_val;
    IN_Q = q_val;
    IN_E = e_val;
    @(negedge clk);
end endtask



task you_pass_task; begin
$display ("----------------------------------------------------------------------------------------------------------------------");
$display ("                                                  Congratulations!                                                    ");
$display ("                                           You have passed all patterns!                                              ");
$display ("----------------------------------------------------------------------------------------------------------------------");
$finish; 
end endtask
endmodule