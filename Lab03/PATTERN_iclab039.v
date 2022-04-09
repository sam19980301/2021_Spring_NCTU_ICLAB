
`ifdef RTL
    `define CYCLE_TIME 15.0
`endif
`ifdef GATE
    `define CYCLE_TIME 15.0
`endif

module PATTERN(
    // Output signals
	clk,
    rst_n,
	in_valid1,
	in_valid2,
	in,
	in_data,
    // Input signals
    out_valid1,
	out_valid2,
    out,
	out_data
);

output reg clk, rst_n, in_valid1, in_valid2;
output reg [1:0] in;
output reg [8:0] in_data;
input out_valid1, out_valid2;
input [2:0] out;
input [8:0] out_data;

// ===============================================================
// Parameters & Integer Declaration
// ===============================================================
parameter N_PATTERN = 500;

integer input_file, read_maze; // I/O return value
integer gap; // random gap cycle
integer i,j;
integer pos_i, pos_j; // position in 2d index
integer trapped; // trapped flag
integer total_hostage, found_hostage; // counting hostage
integer hostage_pos_i[3:0], hostage_pos_j[3:0]; // position of hostage
integer cycle_count, output_cycle_count; 
integer undecoded_pwd[3:0]; // undecoded password for each hostage
integer temp, pwd; // temp int
integer max, min, half_of_range; // intermediate variable used for decoding password
integer pattern_count; // counting pattern

// ===============================================================
// Wire & Reg Declaration
// ===============================================================
reg [1:0] maze[18:0][18:0];
reg signed [8:0] gt_decoded_pwd[3:0]; // ground truth decoded password

// ===============================================================
// Clock
// ===============================================================
always	#(`CYCLE_TIME/2.0) clk = ~clk;
initial	clk = 0;

// ===============================================================
// Initial
// ===============================================================
initial begin
    rst_n = 1'b1;
	in_valid1 = 1'b0;
	in_valid2 = 1'b0;
	in = 2'bx;
	in_data = 9'bx;

    force clk = 0;
    reset_task; // trigger rst_n signal

    input_file  = $fopen("../00_TESTBED/input.txt","r");
    @(negedge clk); // all input signals are synchronized at negative edge of clock

    for (pattern_count=0;pattern_count<N_PATTERN;pattern_count=pattern_count+1) begin
        input_data;
        check_process;
        $display("PASS PATTERN NO.%4d, Cycles: %4d", pattern_count , cycle_count);
    end
    $display("GRATS! PASS ALL PATTERNS.");
    $finish;
end

always @(*) begin
    if (out_valid1 && out_valid2) begin // TBD should consider X to be more robust
        $display("SPEC 5 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 5 IS FAIL!               ");
        // $display("---------------------------------------------");
        // $display("SPEC 5.1. The out_valid1 and out_valid2 should not be high at the same time.");
        // $display("i.e. The start/continue and finish of running the maze is declared at the same time.");
        // $display("out_valid1 %01b", out_valid1);
        // $display("out_valid2 %01b", out_valid2);
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;
    end
    else if ((out_valid1 || out_valid2) && (in_valid1 || in_valid2)) begin
        $display("SPEC 5 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 5 IS FAIL!               ");
        // $display("---------------------------------------------");
        // $display("SPEC 5.2. The out_valid1, out_valid2 should not be high when in_valid1 or in_valid2 is high.");
        // $display("i.e. The input and output signal is triggered at the same time.");
        // $display("out_valid1 %01b", out_valid1);
        // $display("out_valid2 %01b", out_valid2);
        // $display("in_valid1 %01b", in_valid1);
        // $display("in_valid2 %01b", in_valid2);
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;
    end
    else ;
end

// If it is allowed that out changes when out is pulled down
// always @(negedge out_valid2) begin
//     if (out !== 3'd0) begin

always @(*) begin
    if ((out_valid2 === 0) && (out !== 3'd0)) begin
        $display("SPEC 4 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 4 IS FAIL!               ");
        // $display("---------------------------------------------");
        // $display("The out should be reset after your out_valid2 is pulled downed.");
        // $display("i.e. Signal out should be zeroed when not running maze");
        // $display("out_valid2 %01b", out_valid2);
        // $display("out %03b", out);
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;
    end else ;
end

always @(*) begin
    if ((out_valid2 === 1) && (out_data !== 0)) begin
        $display("SPEC 7 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 7 IS FAIL!               ");
        // $display("---------------------------------------------");
        // $display("The out should be correct when out_valid2 is high. (Including the trap)");
        // $display("SPEC 7.4. The out_data should be 0.");
        // $display("i.e. Password result %09d should be zeroed when running the maze.",out_data);
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;
    end
    else if ((out_valid1 === 0) && (out_data !== 0)) begin
        $display("SPEC 11 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 11 IS FAIL!              ");
        // $display("---------------------------------------------");
        // $display("The out_data should be reset after out_valid1 is pulled down.");
        // $display("i.e. When not finishing the maze, out_data should be zeroed.");
        // $display("out_valid1 %01b", out_valid1);
        // $display("out_data %09d", out_data);
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;
    end
end

always @(*) begin
    if (cycle_count == 3000) begin
        $display("SPEC 6 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 6 IS FAIL!               ");
        // $display("---------------------------------------------");
        // $display("The execution latency is over 3000 cycles.");
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;
    end
end


// SPEC 3 IS FAIL! (Done)
// SPEC 4 IS FAIL! (Done)
// SPEC 5 IS FAIL! (Done)
// SPEC 6 IS FAIL! (Done)
// SPEC 7 IS FAIL! (7.0 Done) (7.1 Done) (7.3.1 Done) (7.3.2 Done) (7.4 Done) 
// SPEC 8 IS FAIL! (8.1 Done) (8.2 Done)
// SPEC 9 IS FAIL! (9.1 Done) (9.2 Done)
// SPEC 10 IS FAIL! (Done)
// SPEC 11 IS FAIL! (Done)

task reset_task; begin
    #(15) rst_n = 0; // TBD confirm the #(timing) usage
    #(10);
    if ((out_valid1 !== 0) || (out_valid2 !== 0) || (out !== 0) || (out_data !== 0))  begin
        $display("SPEC 3 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 3 IS FAIL!               ");
        // $display("---------------------------------------------");
        // $display("The reset signal (rst_n) would be given only once at the beginning of simulation.");
        // $display("All output signals should be reset after the reset signal is asserted.");
        // $display("i.e. Output signals is not reset.");
        // $display("out_valid1 %01b", out_valid1);
        // $display("out_valid2 %01b", out_valid2);
        // $display("out %03b", out);
        // $display("out_data %09d", out_data);
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;
    end
    #(10); rst_n = 1;
    #(3.0); release clk;
end endtask

task input_data; begin
    gap = $urandom_range(2,4); // the next pattern will come in 2~4 clocks after out_valid1 is pulled down
    repeat(gap) @(negedge clk);
    in_valid1 = 1'b1;
    // zero / wall four coner
    for (i=0; i<18; i=i+1) maze[0][i] = 0;
    for (i=0; i<18; i=i+1) maze[i][0] = 0;
    for (i=0; i<18; i=i+1) maze[18][i] = 0;
    for (i=0; i<18; i=i+1) maze[i][18] = 0;
    
    // read maze from file and count the hostage
    total_hostage = 0;
    for (i=1; i<18; i=i+1) begin
        for (j=1; j<18; j=j+1) begin
            read_maze = $fscanf (input_file, "%d", maze[i][j]);
            if (maze[i][j] == 2'd3) begin
                total_hostage = total_hostage + 1;
            end 
        end
    end
    // $display("number of hostage : %03d",total_hostage);

    // generate valid and random number based on the number of hostage
    for (i=0;i<4;i=i+1) begin
        hostage_pos_i[temp] = 0;
        hostage_pos_j[temp] = 0;
    end
    temp = 0;
    for (i=1; i<18; i=i+1) begin
        for (j=1; j<18; j=j+1) begin
            if (maze[i][j] == 2'd3) begin
                if ((total_hostage==2) || (total_hostage==4)) begin
                    pwd[3:0] = $urandom_range(0,9)+3;
                    pwd[7:4] = $urandom_range(0,9)+3;
                    pwd[8] = $urandom_range(0,1);
                end 
                else begin
                    pwd[0] = $urandom_range(0,1);
                    pwd[1] = $urandom_range(0,1);
                    pwd[2] = $urandom_range(0,1);
                    pwd[3] = $urandom_range(0,1);
                    pwd[4] = $urandom_range(0,1);
                    pwd[5] = $urandom_range(0,1);
                    pwd[6] = $urandom_range(0,1);
                    pwd[7] = $urandom_range(0,1);
                    pwd[8] = $urandom_range(0,1);
                end
                undecoded_pwd[temp] = pwd[8:0];
                hostage_pos_i[temp] = i;
                hostage_pos_j[temp] = j;
                temp = temp + 1;
            end 
        end
    end
    for (i=temp;i<4;i=i+1) begin
        undecoded_pwd[i] = -256; // minimum 9-bit 2'complement value
    end

    // feeding value to port
    for (i=1; i<18; i=i+1) begin
        for (j=1; j<18; j=j+1) begin
            in = maze[i][j];
            @(negedge clk);
        end
    end
    in_valid1 = 1'b0;
    in_data = 9'bx;
    in = 2'bx;
end endtask

task check_process; begin
    pos_i = 1;
    pos_j = 1;
    cycle_count = 0;
    found_hostage = 0;

    // It is allowed that out_valied2 stays low for more than half a cycle after receiving all 289-cycle singals
    //  @(negedge clk); // if not allowed

    while (!out_valid2) begin
        @(negedge clk);
        cycle_count = cycle_count + 1;
    end
    
    while (!out_valid1) begin
        if (out_valid2) begin 
            case (out) // move according to the out signal
                3'd0: begin pos_i = pos_i; pos_j = pos_j + 1; end // R
                3'd1: begin pos_i = pos_i + 1; pos_j = pos_j; end // B
                3'd2: begin pos_i = pos_i; pos_j = pos_j - 1; end // L
                3'd3: begin pos_i = pos_i - 1; pos_j = pos_j; end // T
                3'd4: begin pos_i = pos_i; pos_j = pos_j; end // S
                default: begin
                    $display("SPEC 7 IS FAIL!");
                    // $display("---------------------------------------------");
                    // $display("               SPEC 7 IS FAIL!               ");
                    // $display("---------------------------------------------");
                    // $display("The out should be correct when out_valid2 is high. (Including the trap)");
                    // $display("SPEC 7.0 The out signal should be within the range [0,4]");
                    // $display("out signal is %03d", out);
                    // $display($time);
                    // repeat(5)@(negedge clk);
                    $finish;
                end
            endcase

            // Correct output means: 
            // (1) the controller goes from starting point to the finish point and rescues the hostage without hitting the wall. 
            // (2) The controller can go back and forth on the same path multiple times. (Skip)
            // (3) If the controller is trapped, out should be 3’d4. 
            // (4) The out_data should be 0.
            if (maze[pos_i][pos_j] == 2'd0) begin // hit the wall
                $display("SPEC 7 IS FAIL!");
                // $display("---------------------------------------------");
                // $display("               SPEC 7 IS FAIL!               ");
                // $display("---------------------------------------------");
                // $display("The out should be correct when out_valid2 is high. (Including the trap)");
                // $display("SPEC 7.1.1. The controller goes from starting point to the finish point and rescues the hostage without hitting the wall.");
                // $display("i.e. Hitting the wall at %03d row %03d col.",pos_i-1,pos_j-1);
                // $display($time);
                // repeat(5)@(negedge clk);
                $finish;
            end else ;

            if (maze[pos_i][pos_j] == 2'd3) begin // meet the hostage
                found_hostage = found_hostage + 1; // the same hostage should be rescued only once
            end

            if (trapped == 1) begin // meet the trap
                if (out === 3'd4) trapped = 0; // trap and correctly stop once
                else begin
                    $display("SPEC 7 IS FAIL!");
                    // $display("---------------------------------------------");
                    // $display("               SPEC 7 IS FAIL!               ");
                    // $display("---------------------------------------------");
                    // $display("The out should be correct when out_valid2 is high. (Including the trap)");
                    // $display("SPEC 7.3.1. If the controller is trapped, out should be 3’d4.");
                    // $display("i.e. Not staying when trapped at %03d row %03d col.",pos_i-1,pos_j-1);
                    // $display($time);
                    // repeat(5)@(negedge clk);
                    $finish;
                end
            end
            else begin // normal case
                // Additional information from Facebook discussion:
                // If the player is on the trap and also stall for one cycle, he must leave the trap for next cycle.
                if (out === 3'd4) begin // stop when not trapped or stop for too long
                    $display("SPEC 7 IS FAIL!");
                    // $display("---------------------------------------------");
                    // $display("               SPEC 7 IS FAIL!               ");
                    // $display("---------------------------------------------");
                    // $display("The out should be correct when out_valid2 is high. (Including the trap)");
                    // $display("SPEC 7.3.2. If the controller is not trapped, out should not be 3’d4.");
                    // $display("i.e. Not moving when not trapped at %03d row %03d col.",pos_i-1,pos_j-1);
                    // $display($time);
                    // repeat(5)@(negedge clk);
                    $finish;
                end else ;
                if (maze[pos_i][pos_j] == 2'd2) trapped = 1; else ;
            end

            // if (out_data !== 0) begin
            //     $display("SPEC 7 IS FAIL!");
            //     // $display("---------------------------------------------");
            //     // $display("               SPEC 7 IS FAIL!               ");
            //     // $display("---------------------------------------------");
            //     // $display("The out should be correct when out_valid2 is high. (Including the trap)");
            //     // $display("SPEC 7.4. The out_data should be 0.");
            //     // $display("i.e. Password result %09d should be zeroed when running the maze.",out_data);
            //     // $display($time);
            //     // repeat(5)@(negedge clk);
            //     $finish;
            // end
            @(negedge clk);
            cycle_count = cycle_count + 1;
        end
        else begin 
            if (
                ((pos_i == 17) && (pos_j == 17)) ||
                ((pos_i == hostage_pos_i[0]) && (pos_j == hostage_pos_j[0])) ||
                ((pos_i == hostage_pos_i[1]) && (pos_j == hostage_pos_j[1])) ||
                ((pos_i == hostage_pos_i[2]) && (pos_j == hostage_pos_j[2])) ||
                ((pos_i == hostage_pos_i[3]) && (pos_j == hostage_pos_j[3]))
            ) begin
                if (!((pos_i == 17) && (pos_j == 17))) begin
                    gap = $urandom_range(2,4);
                    repeat(gap) @(negedge clk);
                    if ((pos_i == hostage_pos_i[0]) && (pos_j == hostage_pos_j[0])) begin
                        in_valid2 = 1;
                        in_data = undecoded_pwd[0];
                        maze[pos_i][pos_j] = 1;
                        hostage_pos_i[0] = 0; // reset hostage position to avoid rescuing again
                        hostage_pos_j[0] = 0;
                    end
                    else if ((pos_i == hostage_pos_i[1]) && (pos_j == hostage_pos_j[1])) begin
                        in_valid2 = 1;
                        in_data = undecoded_pwd[1];
                        maze[pos_i][pos_j] = 1;
                        hostage_pos_i[1] = 0;
                        hostage_pos_j[1] = 0;
                    end
                    else if ((pos_i == hostage_pos_i[2]) && (pos_j == hostage_pos_j[2])) begin
                        in_valid2 = 1;
                        in_data = undecoded_pwd[2];
                        maze[pos_i][pos_j] = 1;
                        hostage_pos_i[2] = 0;
                        hostage_pos_j[2] = 0;
                    end
                    else if ((pos_i == hostage_pos_i[3]) && (pos_j == hostage_pos_j[3])) begin
                        in_valid2 = 1;
                        in_data = undecoded_pwd[3];
                        maze[pos_i][pos_j] = 1;
                        hostage_pos_i[3] = 0;
                        hostage_pos_j[3] = 0;
                    end
                    else ;
                    @(negedge clk); // high for one cycle
                    cycle_count = cycle_count + 1;
                    in_valid2 = 0;
                    in_data = 9'bx;

                    while (!out_valid2) begin
                        @(negedge clk);
                        cycle_count = cycle_count + 1;
                    end
                end
                else begin
                    @(negedge clk);
                    cycle_count = cycle_count + 1;
                end
                
            end
            else begin
                $display("SPEC 8 IS FAIL!");
                // $display("---------------------------------------------");
                // $display("               SPEC 8 IS FAIL!               ");
                // $display("---------------------------------------------");
                // $display("SPEC 8.1. When pull down the out_valid2, the location of controller should be in the location of hostage or the exit.");
                // $display("i.e. %03d row %03d col is not an endpath or endpoint when breaking the game.",pos_i-1,pos_j-1);
                // $display($time);
                // repeat(5)@(negedge clk);
                $finish;
            end
        end
        // @(negedge clk);
    end
    
    // Finish the maze
    // It is violated by SPEC 8 rather then SPEC 7
    // Testing SPEC 8.2
    // if (!( (found_hostage == total_hostage + 1) && (pos_i==17) && (pos_j==17) )) begin
    if (!( (found_hostage == total_hostage) && (pos_i==17) && (pos_j==17) )) begin
        $display("SPEC 8 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 8 IS FAIL!               ");
        // $display("---------------------------------------------");
        // $display("SPEC 8.2. When pull down the out_valid2, the location of controller should be in the location of hostage or the exit.");
        // $display("i.e. Not yet find all hostage or reach to endpoint.");
        // $display("Found hostage: %03d / %03d",found_hostage,total_hostage);
        // $display("Position: %03d / %03d",pos_i-1,pos_j-1);
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;

        // $display("SPEC 7 IS FAIL!");
        // // $display("---------------------------------------------");
        // // $display("               SPEC 7 IS FAIL!               ");
        // // $display("---------------------------------------------");
        // // $display("The out should be correct when out_valid2 is high. (Including the trap)");
        // // $display("SPEC 7.1.2. The controller goes from starting point to the finish point and rescues the hostage without hitting the wall.");
        // // $display("i.e. Not yet find all hostage or reach to endpoint.");
        // // $display("Found hostage: %03d / %03d",found_hostage,total_hostage);
        // // $display("Position: %03d / %03d",pos_i-1,pos_j-1);
        // // $display($time);
        // // repeat(5)@(negedge clk);
        // $finish;
    end

    // calculate the ground truth answer
    for (i=0;i<4;i=i+1) begin
        gt_decoded_pwd[i] = undecoded_pwd[i];
    end
    // $display("Start\n");
    // for (i=0;i<4;i=i+1) begin
    //     $display("%09b",gt_decoded_pwd[i]);
    // end
    // $display("\n");

    // sorting
    for (i=0;i<3;i=i+1) begin
        for (j=i+1;j<4;j=j+1) begin
            if (gt_decoded_pwd[i] < gt_decoded_pwd[j]) begin
                temp = gt_decoded_pwd[i];
                gt_decoded_pwd[i] = gt_decoded_pwd[j];
                gt_decoded_pwd[j] = temp; 
            end
        end
    end
    // $display("Sort\n");
    // for (i=0;i<4;i=i+1) begin
    //     $display("%09b",gt_decoded_pwd[i]);
    // end
    // $display("\n");

    // excess 3
    if ((total_hostage==2) || (total_hostage==4)) begin
        for (i=0;i<4;i=i+1) begin
            temp = (gt_decoded_pwd[i][3:0]-3) + 10 * (gt_decoded_pwd[i][7:4]-3);
            gt_decoded_pwd[i] = (gt_decoded_pwd[i][8]==1) ? -temp : temp; 
        end
    end else ;
    // $display("EX3\n");
    // for (i=0;i<4;i=i+1) begin
    //     $display("%09b",gt_decoded_pwd[i]);
    // end
    // $display("\n");

    // subtract half of range
    if (total_hostage>1) begin
        max = (gt_decoded_pwd[0] > gt_decoded_pwd[1]) ? gt_decoded_pwd[0] : gt_decoded_pwd[1];
        if (total_hostage > 2) max = (max > gt_decoded_pwd[2]) ? max : gt_decoded_pwd[2];
        if (total_hostage > 3) max = (max > gt_decoded_pwd[3]) ? max : gt_decoded_pwd[3];

        min = (gt_decoded_pwd[0] < gt_decoded_pwd[1]) ? gt_decoded_pwd[0] : gt_decoded_pwd[1];
        if (total_hostage > 2) min = (min < gt_decoded_pwd[2]) ? min : gt_decoded_pwd[2];
        if (total_hostage > 3) min = (min < gt_decoded_pwd[3]) ? min : gt_decoded_pwd[3];

        half_of_range = (max + min)/2;

        for (i=0;i<4;i=i+1) begin
            gt_decoded_pwd[i] = gt_decoded_pwd[i] - half_of_range;
        end
    end
    // $display("SUBSTRACT HALF RANGE\n");
    // for (i=0;i<4;i=i+1) begin
    //     $display("%09b",gt_decoded_pwd[i]);
    // end
    // $display("\n");

    // cumulation
    if (total_hostage>2) begin
        gt_decoded_pwd[0] = gt_decoded_pwd[0];
        gt_decoded_pwd[1] = ((2*gt_decoded_pwd[0])+(1*gt_decoded_pwd[1]))/3;
        gt_decoded_pwd[2] = ((2*gt_decoded_pwd[1])+(1*gt_decoded_pwd[2]))/3;
        gt_decoded_pwd[3] = ((2*gt_decoded_pwd[2])+(1*gt_decoded_pwd[3]))/3;
    end
    // $display("CUMULATION\n");
    // for (i=0;i<4;i=i+1) begin
    //     $display("%09b",gt_decoded_pwd[i]);
    // end
    // $display("\n");
    
    // consider no hostage situation
    if (total_hostage==0) gt_decoded_pwd[0] = 0;

    output_cycle_count = 0;
    while (out_valid1) begin
        // $display("%09b",out_data);
        if (output_cycle_count < ((total_hostage != 0) ? total_hostage : 1)) begin
            if (out_data !== gt_decoded_pwd[output_cycle_count]) begin
                $display("SPEC 10 IS FAIL!");
                // $display("---------------------------------------------");
                // $display("               SPEC 10 IS FAIL!              ");
                // $display("---------------------------------------------");
                // $display("The out_data should be correct when out_valid1 is high.");
                // $display("i.e. The %03d th out_data should be %09d password rather than %09d.", output_cycle_count+1 ,gt_decoded_pwd[output_cycle_count], out_data);
                // $display($time);
                // repeat(5)@(negedge clk);
                $finish;
            end else ;
        end
        else begin // out_valid1 be high too long
            $display("SPEC 9 IS FAIL!");
            // $display("---------------------------------------------");
            // $display("               SPEC 9 IS FAIL!               ");
            // $display("---------------------------------------------");
            // $display("SPEC 9.1. The out_valid1 should maintain the corresponding clock cycles.");
            // $display("i.e. The output contains %03d password while total_hostage is %03d.", output_cycle_count+1, total_hostage);
            // $display($time);
            // repeat(5)@(negedge clk);
            $finish;
        end
        output_cycle_count = output_cycle_count + 1;
        @(negedge clk);
    end
    if (!(output_cycle_count == ((total_hostage != 0) ? total_hostage : 1))) begin // out_valid1 be high too short
        $display("SPEC 9 IS FAIL!");
        // $display("---------------------------------------------");
        // $display("               SPEC 9 IS FAIL!               ");
        // $display("---------------------------------------------");
        // $display("SPEC 9.2 The out_valid1 should maintain the corresponding clock cycles.");
        // $display("i.e. The output contains %03d password while total_hostage is %03d.", output_cycle_count+1, total_hostage);
        // $display($time);
        // repeat(5)@(negedge clk);
        $finish;
    end
end endtask

endmodule