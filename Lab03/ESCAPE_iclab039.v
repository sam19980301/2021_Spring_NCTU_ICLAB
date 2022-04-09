module ESCAPE(
    //Input Port
    clk,
    rst_n,
    in_valid1,
    in_valid2,
    in,
    in_data,
    //Output Port
    out_valid1,
    out_valid2,
    out,
    out_data
);

//==================INPUT OUTPUT==================//
input clk, rst_n, in_valid1, in_valid2;
input [1:0] in;
input [8:0] in_data;    
output reg	out_valid1, out_valid2;
output reg [2:0] out;
output reg [8:0] out_data;

// =======Parameters & Integer Declaration========//
parameter STATE_IDLE = 3'd0;
parameter STATE_INPUT = 3'd1;
parameter STATE_CALC = 3'd2; // running maze
parameter STATE_DECODE = 3'd3;
parameter STATE_OUTPUT = 3'd4;

//==================Register=======================//
reg [2:0] current_state, next_state;
reg [8:0] cnt, current_position;
reg [1:0] maze [360:0];
reg [8:0] pwd_array[3:0];
wire [8:0] decoded_array[3:0];
reg [1:0] right_block, down_block, left_block, up_block; // four direction information
reg [2:0] total_hostage, found_hostage;
wire [1:0] calc_type; // calc_type = total_hostage - 1
reg [2:0] stop; // stop flag/counter
reg [2:0] next_move; // next move
reg [1:0] curr_move; // current move
reg is_endpath; // endpath flag

integer ii;

// state FSM
// current state
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) current_state <= STATE_IDLE;
    else current_state <= next_state;
end

// next state
always @(*) begin
    if (!rst_n) next_state = STATE_IDLE;
    else begin
        case (current_state)
            STATE_IDLE: begin // idle & read first input
                if (in_valid1) next_state = STATE_INPUT;
                else next_state = current_state;
                // Testing SPEC 6
                // next_state = current_state;
            end
            STATE_INPUT: begin // read input
                if (!in_valid1) next_state = STATE_CALC; // one cycle idle after 289 sequential maze input
                else next_state = current_state;
            end
            STATE_CALC: begin // solving maze
                if ((found_hostage==total_hostage) && (current_position==340)) next_state = STATE_DECODE; // potential resource sharing with out & out_valid2 signal condition
                else next_state = current_state;
            end
            STATE_DECODE: begin // decoding the password, may not be needed or could be optimized, just in case the it could finish the pipeline
                if (cnt == 3) next_state = STATE_OUTPUT;
                else next_state = current_state;
            end
            STATE_OUTPUT: begin // output decoded password
                // Testing SPEC 9.1 (Part.1)
                // if ((cnt == total_hostage) || (total_hostage == 0)) next_state = STATE_IDLE;
                // Testing SPEC 9.2 (Part.1)
                // if ((cnt == total_hostage - 2) || (total_hostage == 0)) next_state = STATE_IDLE;
                if ((cnt == total_hostage - 1) || (total_hostage == 0)) next_state = STATE_IDLE;
                else next_state = current_state;
            end
            default: next_state = current_state;
        endcase
    end
end

// output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid1 <= 0;
        out_data <= 0;
        // Testing SPEC 3
        // out_valid1 <= 1;
        // out_data <= 1;
    end
    else begin
        if (current_state == STATE_OUTPUT) begin
            if (found_hostage == 0) begin // if no hostage then output zero for one cycle
                out_valid1 <= 1;
                out_data <= 0;
                // Testing SPEC 5.1
                // out_valid2 <= 1;
                // out_valid2 <= 1'bx; // Unknow vlaue will not trigger the error
            end
            // Testing SPEC 9.1 (Part.2)
            // else if (cnt == found_hostage) begin // output decoded password sequentially
            //     out_valid1 <= 1;
            //     out_data <= decoded_array[0];
            // end
            else if (cnt < found_hostage) begin // output decoded password sequentially
                out_valid1 <= 1;
                out_data <= decoded_array[cnt];
                // Testing SPEC 10
                // out_data <= 0;
            end
            // Testing SPEC 9.2 (Part.2)
            // else if (cnt < found_hostage - 1) begin // output decoded password sequentially
            //     out_valid1 <= 1;
            //     out_data <= decoded_array[cnt];
            // end
            else begin
                out_valid1 <= 0;
                out_data <= 0;
            end
        end
        // Testing SPEC 7.4
        // else if (current_state == STATE_CALC) begin
        //     out_valid1 <= 0;
        //     out_data <= 1;
        // end
        else begin
            out_valid1 <= 0;
            out_data <= 0;
            // Testing SPEC 11
            // out_data <= 1;
        end
    end
end

// Idea
// CYCLE        t_0             t_1             t_2             t_3             t_4             t_5
// CURRENT_POS  A               B               C               D               E               F
// OUTPUT_MOVE  OtoA            AtoB            BtoC            CtoD            DtoE            EtoF    (synch w NEXT_MOVE)

// NEXT_MOVE            AtoB            BtoC            CtoD            DtoE            EtoF
// CURR_MOVE    save next_move(outptu_move) to handle trap/hostage situation

// output move information and update the required information for next cycle
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid2 <= 0;
        out <= 0;
        current_position <= 20;
        curr_move <= 0;
        stop <= 0;
    end
    // Testing SPEC 5.2
    // else if (current_state==STATE_INPUT) out_valid2 <= 1;
    else if ((current_state==STATE_INPUT) && (!in_valid1)) begin // one idle last cycle could be used for initalization
        out_valid2 <= 0;
        out <= 0;
        // Testing SPEC 4
        // out <= 4;
        current_position <= 20;
        curr_move <= 0;
        stop <= 0;
    end
    // Testing SPEC 6
    // else if (current_state==STATE_CALC) begin
    //     out_valid2 <= 0;
    //     out <= 0;
    // end
    else if (current_state==STATE_CALC) begin
        if ((maze[current_position]==2) && (stop==0)) begin // if meet trap and not yet stop before, then stop for one cycle and move
            out_valid2 <= 1;
            out <= 4;
            // Testing SPEC 7.3.1
            // out <= 0;
            current_position <= current_position;
            curr_move <= curr_move;
            stop <= 1;
        end
        else if ((maze[current_position]==3) && (stop<6)) begin // if meet hostage and not yet stop before, then stop for several cycles and move
            // celling(0.5 (pos/neg diff) + 4 (wait) + 1 (high)) = 6
            out_valid2 <= 0;
            out <= 0;
            current_position <= current_position;
            curr_move <= curr_move;
            stop <= stop + 1;
        end
        else if ((found_hostage == total_hostage) && (current_position == 340)) begin // if meet all hostages and meet the endpoint, then finish the maze
            out_valid2 <= 0;
            out <= 0;
            current_position <= current_position;
            curr_move <= curr_move;
            stop <= 1;
        end
        // Testign SPEC 8.1 (Testing SPEC 8.2. is included in PATTERN.v)
        // else if ($urandom_range(0,5)==5) begin
        //     out_valid2 <= 0;
        //     out <= 0;
        // end
        else begin // normal case, move according to given strategy
            out_valid2 <= 1;
            out <= next_move;
            // Testing SPEC 7.0
            // out <= 5;
            // Testing SPEC 7.3.2
            // out <= 4;
            case (next_move)
                0: current_position <= current_position + 1; // RIGHT
                1: current_position <= current_position + 19; // DOWN
                2: current_position <= current_position - 1; // LEFT
                3: current_position <= current_position -19; // UP
                4: current_position <= current_position; // STALL (will not be used here)
                default: current_position <= current_position;
            endcase
            curr_move <= next_move;
            stop <= 0; // not stop
        end
    end
    else begin
        out_valid2 <= 0;
        out <= 0;
        current_position <= current_position;
        curr_move <= curr_move;
        stop <= stop;
    end
end

// counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 0;
    else begin
        case (current_state)
            STATE_IDLE: cnt <= 21; // the initial index for STATE_INPUT
            STATE_INPUT: begin
                if (in_valid1) begin
                    if (cnt%19==17) cnt <= cnt + 3; // jump last cell in current layer & first cell in next layer
                    else cnt <= cnt + 1;
                end else cnt <= cnt;
            end
            STATE_CALC: cnt <= 0;
            STATE_DECODE: if (cnt == 3) cnt <= 0; else cnt <= cnt + 1;
            STATE_OUTPUT: cnt <= cnt + 1;
            default: cnt <= 0;
        endcase
    end
end

// read maze information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (ii=0;ii<361;ii=ii+1) begin
           maze[ii] <= 0;
        end
    end
    else begin
        case (current_state)
            STATE_IDLE: begin
                for (ii=0;ii<20;ii=ii+1) begin
                    maze[ii] <= 0;
                end
                maze[20] <= 1; // starting point must be 1, skip reading in singal
                for (ii=21;ii<361;ii=ii+1) begin
                    maze[ii] <= 0;
                end
            end
            STATE_INPUT: begin
                if (in_valid1) begin
                   maze[cnt] <= in; // potential area optimization using linked list rather indexing to I/O data
                end else ;
            end
            STATE_CALC: begin
                if (
                    (in_valid2) ||
                    (is_endpath && maze[current_position]==1) && (current_position != 340) || // improve by ~8%
                    (is_endpath && maze[current_position]==2) && (stop==1) // improve by ~5%
                )
                maze[current_position] <= 0;
                // setting hostage tile to wall tile after resecuing hostage
                // setting path tile to wall tile if it is an endpath and not a endpoint
                // setting trap tile to wall tile if it is an endpath
                else;
            end
            default: begin
                for (ii=0;ii<361;ii=ii+1) begin
                    maze[ii] <= maze[ii];
                end
            end
        endcase
    end
end

// counting number of total hostage
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        total_hostage <= 0;
    end
    else if (current_state==STATE_IDLE) total_hostage <= 0; // hostage will not appear at starting point
    else if ((current_state==STATE_INPUT) && (in_valid1) && (in==3)) total_hostage <= total_hostage + 1;
    else total_hostage <= total_hostage;
end

// counting number of found hostage
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        found_hostage <= 0;
    end
    else if (current_state==STATE_IDLE) found_hostage <= 0;
    else if ((current_state==STATE_CALC) && (in_valid2)) found_hostage <= found_hostage + 1;
    else found_hostage <= found_hostage;
end

// read password information when rescuing hostage
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        for (ii=0;ii<4;ii=ii+1) pwd_array[ii] <= -256; // minimum value for 9 bit signed integer
    end
    else begin
        case (current_state)
            STATE_IDLE: for (ii=0;ii<4;ii=ii+1) pwd_array[ii] <= -256;
            STATE_CALC: begin
                if (in_valid2) begin 
                    pwd_array[found_hostage] <= in_data;
                end else ;
            end 
            default: begin
                for (ii=0;ii<4;ii=ii+1) begin
                    pwd_array[ii] <= pwd_array[ii];
                end
            end
        endcase
    end
end

// Moving stategy: avoid going backward by using the last move information
// 0: right, 1:down, 2:left, 3: up (clockwise)
always @(*) begin
    if (!rst_n) begin
        next_move = 0;
        is_endpath = 0;
    end
    else begin
        right_block = maze[current_position+1];
        down_block = maze[current_position+19];
        left_block = maze[current_position-1];
        up_block = maze[current_position-19];
        
        if (
        ( (right_block==0) && (down_block==0) && ((left_block==0)) && ((up_block!=0)) ) ||
        ( (right_block==0) && (down_block==0) && ((left_block!=0)) && ((up_block==0)) ) ||
        ( (right_block==0) && (down_block!=0) && ((left_block==0)) && ((up_block==0)) ) ||
        ( (right_block!=0) && (down_block==0) && ((left_block==0)) && ((up_block==0)) )
        ) begin // check endpath or not
            is_endpath = 1;
        end
        else begin
            is_endpath = 0;
        end

        if ((up_block != 0) && (curr_move<=0)) next_move = 3;
        else if ((right_block != 0) && (curr_move<=1)) next_move = 0;
        else if ((down_block != 0) && (curr_move<=2)) next_move = 1;
        else if (left_block != 0) next_move = 2;
        else if (up_block != 0) next_move = 3;
        else if (right_block != 0) next_move = 0;
        else next_move = 1;
        // Testing SPEC 7.1
        // next_move = 0;

        // case (curr_move)
        //     0: begin
        //         if (up_block != 0) next_move = 3;
        //         else if (right_block != 0) next_move = 0;
        //         else if (down_block != 0) next_move = 1;
        //         else next_move = 2;
        //     end
        //     1: begin
        //         if (right_block != 0) next_move = 0;
        //         else if (down_block != 0) next_move = 1;
        //         else if (left_block != 0) next_move = 2;
        //         else next_move = 3;
        //     end
        //     2: begin
        //         if (down_block != 0) next_move = 1;
        //         else if (left_block != 0) next_move = 2;
        //         else if (up_block != 0) next_move = 3;
        //         else next_move = 0;
        //     end
        //     3: begin
        //         if (left_block != 0) next_move = 2;
        //         else if (up_block != 0) next_move = 3;
        //         else if (right_block != 0) next_move = 0;
        //         else next_move = 1;
        //     end
        //     default: next_move = 0;
        // endcase
    end
end

// decoding password module
assign calc_type = total_hostage - 1;
DECODER MYDECODER(
    .clk(clk),
    .in_n0(pwd_array[0]),
    .in_n1(pwd_array[1]),
    .in_n2(pwd_array[2]),
    .in_n3(pwd_array[3]),
    .calc_type(calc_type),
    .out_n0(decoded_array[0]),
    .out_n1(decoded_array[1]),
    .out_n2(decoded_array[2]),
    .out_n3(decoded_array[3])
);

endmodule

// Sequential pipeline circuit used for decoding password
// Combination circuit would incur timing violation
module DECODER (
    clk,
	in_n0,
	in_n1, 
	in_n2, 
	in_n3,
	calc_type,
	out_n0,
    out_n1,
    out_n2,
    out_n3
);

input clk;
input [8:0] in_n0, in_n1 ,in_n2, in_n3;
input [1:0] calc_type; // calc_type = # hostage - 1
output [8:0] out_n0, out_n1, out_n2, out_n3;

reg signed [8:0] signed_n[3:0];
reg cmp[14:0];
reg [2:0] concat[3:0];
reg [1:0] rank[3:0];
// wire signed [8:0] sort_n[3:0];
reg signed [8:0] sort_n[3:0];
reg signed [8:0] sort_n_pipeline[3:0];
reg signed [8:0]  ex3[3:0];
reg signed [8:0]  ex3_pipeline[3:0];
reg signed [8:0] max, min;
wire signed [8:0]  half_range;
wire signed [8:0]  shift[3:0];
reg signed [8:0]  shift_pipeline[3:0];
reg signed [8:0] norm_n[3:0];

// Pipeline
// SORT -> EX3 -> SUB -> CUM

always @(posedge clk) begin
    sort_n_pipeline[0] <= sort_n[0];
    sort_n_pipeline[1] <= sort_n[1];
    sort_n_pipeline[2] <= sort_n[2];
    sort_n_pipeline[3] <= sort_n[3];
end

always @(posedge clk) begin
    ex3_pipeline[0] <= ex3[0];
    ex3_pipeline[1] <= ex3[1];
    ex3_pipeline[2] <= ex3[2];
    ex3_pipeline[3] <= ex3[3];
end

always @(posedge clk) begin
    shift_pipeline[0] <= shift[0];
    shift_pipeline[1] <= shift[1];
    shift_pipeline[2] <= shift[2];
    shift_pipeline[3] <= shift[3];
end

// unsgigned integer to signed integer
always @(*) begin
	signed_n[0] = {in_n0};
	signed_n[1] = {in_n1};
	signed_n[2] = {in_n2};
	signed_n[3] = {in_n3};
end

// compare bit used for ranking
always @(*) begin
	cmp[0] = ( signed_n[0] < signed_n[1] );
	cmp[1] = ( signed_n[0] < signed_n[2] );
	cmp[2] = ( signed_n[0] < signed_n[3] );
	cmp[3] = ( signed_n[1] < signed_n[2] );
	cmp[4] = ( signed_n[1] < signed_n[3] );
	cmp[5] = ( signed_n[2] < signed_n[3] );
end

// concatenate compare bit 
always @(*) begin
	concat[0] = {cmp[0],cmp[1],cmp[2]};
	concat[1] = {~cmp[0],cmp[3],cmp[4]};
	concat[2] = {~cmp[1],~cmp[3],cmp[5]};
	concat[3] = {~cmp[2],~cmp[4],~cmp[5]};
end

// counting bit to sort the array
always @(*) begin
	case (concat[0])
		3'b000: rank[0] = 0 ;
        3'b001: rank[0] = 1 ;
        3'b010: rank[0] = 1 ;
        3'b011: rank[0] = 2 ;
        3'b100: rank[0] = 1 ;
        3'b101: rank[0] = 2 ;
        3'b110: rank[0] = 2 ;
        3'b111: rank[0] = 3 ;
        default: rank[0] = 0; // will not happen
	endcase
	case (concat[1])
		3'b000: rank[1] = 0 ;
        3'b001: rank[1] = 1 ;
        3'b010: rank[1] = 1 ;
        3'b011: rank[1] = 2 ;
        3'b100: rank[1] = 1 ;
        3'b101: rank[1] = 2 ;
        3'b110: rank[1] = 2 ;
        3'b111: rank[1] = 3 ;
        default: rank[1] = 0; // will not happen
	endcase
	case (concat[2])
		3'b000: rank[2] = 0 ;
        3'b001: rank[2] = 1 ;
        3'b010: rank[2] = 1 ;
        3'b011: rank[2] = 2 ;
        3'b100: rank[2] = 1 ;
        3'b101: rank[2] = 2 ;
        3'b110: rank[2] = 2 ;
        3'b111: rank[2] = 3 ;
        default: rank[2] = 0; // will not happen
	endcase
	case (concat[3])
		3'b000: rank[3] = 0 ;
        3'b001: rank[3] = 1 ;
        3'b010: rank[3] = 1 ;
        3'b011: rank[3] = 2 ;
        3'b100: rank[3] = 1 ;
        3'b101: rank[3] = 2 ;
        3'b110: rank[3] = 2 ;
        3'b111: rank[3] = 3 ;
        default: rank[3] = 0; // will not happen
	endcase
end

// sorting
// assign sort_n[0] = (rank[0]==0) ? signed_n[0] : (rank[1]==0) ? signed_n[1] : (rank[2]==0) ? signed_n[2] : signed_n[3];
// assign sort_n[1] = (rank[0]==1) ? signed_n[0] : (rank[1]==1) ? signed_n[1] : (rank[2]==1) ? signed_n[2] : signed_n[3];
// assign sort_n[2] = (rank[0]==2) ? signed_n[0] : (rank[1]==2) ? signed_n[1] : (rank[2]==2) ? signed_n[2] : signed_n[3];
// assign sort_n[3] = (rank[0]==3) ? signed_n[0] : (rank[1]==3) ? signed_n[1] : (rank[2]==3) ? signed_n[2] : signed_n[3];

always @(*) begin
    sort_n[0] = 0;
    sort_n[1] = 0;
    sort_n[2] = 0;
    sort_n[3] = 0;
    
    sort_n[rank[0]] = signed_n[0];
    sort_n[rank[1]] = signed_n[1];
    sort_n[rank[2]] = signed_n[2];
    sort_n[rank[3]] = signed_n[3];
end

// excess-3
always @(*) begin
    if (calc_type[0]) begin // if number of hostage is even, then regard them as excess-3 integer
        ex3[0] = (sort_n_pipeline[0][3:0]-3) + ((sort_n_pipeline[0][7:4]-3) * 10);
        ex3[0] = sort_n_pipeline[0][8]?-ex3[0]:ex3[0];

        ex3[1] = (sort_n_pipeline[1][3:0]-3) + ((sort_n_pipeline[1][7:4]-3) * 10);
        ex3[1] = sort_n_pipeline[1][8]?-ex3[1]:ex3[1];

        ex3[2] = (sort_n_pipeline[2][3:0]-3) + ((sort_n_pipeline[2][7:4]-3) * 10);
        ex3[2] = sort_n_pipeline[2][8]?-ex3[2]:ex3[2];

        ex3[3] = (sort_n_pipeline[3][3:0]-3) + ((sort_n_pipeline[3][7:4]-3) * 10);
        ex3[3] = sort_n_pipeline[3][8]?-ex3[3]:ex3[3];
    end
    else begin // else regard them as 2's complement integer
        ex3[0] = sort_n_pipeline[0];
        ex3[1] = sort_n_pipeline[1];
        ex3[2] = sort_n_pipeline[2];
        ex3[3] = sort_n_pipeline[3];
    end
end

// subtract half of range
always @(*) begin
    max = (ex3_pipeline[0] > ex3_pipeline[1]) ? ex3_pipeline[0] : ex3_pipeline[1];
    max = (calc_type > 1) ? (max > ex3_pipeline[2]) ? max : ex3_pipeline[2] : max;
    max = (calc_type > 2) ? (max > ex3_pipeline[3]) ? max : ex3_pipeline[3] : max;
end
always @(*) begin
    min = (ex3_pipeline[0] < ex3_pipeline[1]) ? ex3_pipeline[0] : ex3_pipeline[1];
    min = (calc_type > 1) ? (min < ex3_pipeline[2]) ? min : ex3_pipeline[2] : min;
    min = (calc_type > 2) ? (min < ex3_pipeline[3]) ? min : ex3_pipeline[3] : min;
end
assign half_range = (max + min) / 2;

assign shift[0] = (calc_type>0) ? ex3_pipeline[0] - half_range : ex3_pipeline[0]; // if number of hostage greater than 1, then subtract half of range
assign shift[1] = (calc_type>0) ? ex3_pipeline[1] - half_range : ex3_pipeline[1];
assign shift[2] = (calc_type>0) ? ex3_pipeline[2] - half_range : ex3_pipeline[2];
assign shift[3] = (calc_type>0) ? ex3_pipeline[3] - half_range : ex3_pipeline[3];

// cumulation
always @(*) begin
	if (calc_type>1) begin // if number of hostage greater than 2, then do the cumulation operatoin
		norm_n[0] = shift_pipeline[0];
		norm_n[1] = ((norm_n[0] * 2) + shift_pipeline[1]) / 3;
		norm_n[2] = ((norm_n[1] * 2) + shift_pipeline[2]) / 3;
		norm_n[3] = ((norm_n[2] * 2) + shift_pipeline[3]) / 3;
	end
	else begin
		norm_n[0] = shift_pipeline[0];
		norm_n[1] = shift_pipeline[1];
		norm_n[2] = shift_pipeline[2];
		norm_n[3] = shift_pipeline[3];
	end
end

assign out_n0 = norm_n[0];
assign out_n1 = norm_n[1];
assign out_n2 = norm_n[2];
assign out_n3 = norm_n[3];

endmodule

// Notes
// A good coding style from TA: Using always block to specify one or few variables that are related