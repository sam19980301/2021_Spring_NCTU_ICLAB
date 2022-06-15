module IDC(
	// Input signals
	clk,
	rst_n,
	in_valid,
	in_data,
	op,
	// Output signals
	out_valid,
	out_data
);

//=========INPUT AND OUTPUT DECLARATION==============//
input		clk;
input		rst_n;
input		in_valid;
input signed [6:0] in_data;
input [3:0] op;

output reg 		  out_valid;
output reg  signed [6:0] out_data;

//==================PARAMETER=====================//
parameter STATE_IDLE = 		'd0;
parameter STATE_INPUT =		'd1;
parameter STATE_CALC =		'd2;
parameter STATE_OUTPUT =	'd3;

parameter MIDPOINT =					'd0;
parameter AVERAGE = 					'd1;
parameter COUNTERCLOCKWISE_ROTATION =	'd2;
parameter CLOCKWISE_ROTATION = 			'd3;
parameter FLIP = 						'd4;
parameter SHIFT_UP = 					'd5;
parameter SHIFT_LEFT = 					'd6;
parameter SHIFT_DOWN = 					'd7;
parameter SHIFT_RIGHT = 				'd8;

parameter UPPER_RIGHT = 4'b1000;
parameter UPPER_LEFT = 	4'b0100;
parameter LOWER_LEFT = 	4'b0010;
parameter LOWER_RIGHT =	4'b0001;

genvar i;
integer x;

//==================Wire & Register===================//
// FSM
reg [1:0]	current_state, next_state;
reg [5:0] 	cnt;

// output
reg signed	[7:0]	out_data_reg;
wire				zoom;

// meta information
reg			[3:0]	current_action;
reg			[2:0]	op_pts		[ 1:0];	// operation points
reg signed 	[7:0]	in_data_arr	[63:0];	// an extra bit to avoid overflow after flip operation
reg			[3:0]	op_arr		[14:0];

// calculation
wire				within_subregion	[63:0];
reg			[3:0]	relative_location	[63:0];
reg					upper_right			[63:0];
reg					upper_left			[63:0];
reg					lower_left			[63:0];
reg					lower_right			[63:0];

// an extra bit to avoid overflow after flip operation
wire	signed	[7:0]	sub_region			[3:0];	// in quadrant order
wire 	signed 	[7:0] 	sort				[5:0];
wire	signed 	[7:0]	midpoint_value;
wire	signed 	[7:0]	average_value;

//==================Design===================//
// FSM
// current state
always @(posedge clk or negedge rst_n) begin
	if (!rst_n)	current_state <= STATE_IDLE;
	else		current_state <= next_state;
end

// next state
always @(*) begin
	if (!rst_n)	next_state = STATE_IDLE;
	else begin
		case (current_state)
			STATE_IDLE:		if (in_valid)	next_state = STATE_INPUT;	else next_state = current_state;
			STATE_INPUT:	if (cnt=='d63)	next_state = STATE_CALC; 	else next_state = current_state;
			STATE_CALC:		if (cnt=='d14)	next_state = STATE_OUTPUT;	else next_state = current_state;
			STATE_OUTPUT:	if (cnt=='d15)	next_state = STATE_IDLE;	else next_state = current_state;
			default:		next_state = current_state;	// will not happen
		endcase
	end
end

// DEBUG
// always @(negedge clk) begin
// 	if (current_state == STATE_CALC) begin
// 		$display("%d th Action: %d",cnt, op_arr[cnt]);
// 		$display(op_pts[0],op_pts[1]);
// 		for (x=0; x<8; x=x+1) begin
// 			$display("%4d %4d %4d %4d %4d %4d %4d %4d",
// 			in_data_arr[x*8+0],
// 			in_data_arr[x*8+1],
// 			in_data_arr[x*8+2],
// 			in_data_arr[x*8+3],
// 			in_data_arr[x*8+4],
// 			in_data_arr[x*8+5],
// 			in_data_arr[x*8+6],
// 			in_data_arr[x*8+7]
// 			);
// 		end
// 	end
// end

// output logic
always @(posedge clk or negedge rst_n) begin
	if (!rst_n)								out_valid <= 0;
	else if (current_state == STATE_OUTPUT)	out_valid <= 1;
	else									out_valid <= 0;
end

always @(*) begin
	out_data = (out_valid) ? out_data_reg : 0;
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n)		out_data_reg <= 'b0;
	else if (zoom)	out_data_reg <= in_data_arr[ (op_pts[0] + cnt[3:2]) * 8 + (op_pts[1] + cnt[1:0] + 9)];
	else			out_data_reg <= in_data_arr[cnt[3:2] * 16 + cnt[1:0] * 2];
end
assign zoom = (op_pts[0]<4) && (op_pts[1]<4);

// action counter information
always @(posedge clk or negedge rst_n) begin
	if (!rst_n)	cnt <= 0;
	else begin
		case (current_state)
			STATE_IDLE:		if (in_valid) 	cnt <= 1;		else cnt <= 0;
			STATE_INPUT:	cnt <= cnt + 1;									// counter of input	 length
			STATE_CALC:		if (cnt!='d14)	cnt <= cnt + 1; else cnt <= 0;	// counter of action length
			STATE_OUTPUT:	cnt[3:0] <= cnt[3:0] + 1;						// counter of output length
			default:		cnt <= cnt;										// will not happen
		endcase
	end
end

// meta information
always @(*) begin
	if (current_state == STATE_CALC)	current_action = op_arr[cnt];
	else								current_action = op_arr[0];
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n)	op_pts[0] <= 0;
	else begin
		case (current_state)
			STATE_IDLE,
			STATE_INPUT:	op_pts[0] <= 'd3;
			STATE_CALC: begin
				case (current_action)
					SHIFT_UP:		if (op_pts[0] != 'd0) op_pts[0] <= op_pts[0] - 1; else op_pts[0] <= op_pts[0];
					SHIFT_DOWN:		if (op_pts[0] != 'd6) op_pts[0] <= op_pts[0] + 1; else op_pts[0] <= op_pts[0];
					default:		op_pts[0] <= op_pts[0];
				endcase
			end
			// STATE_OUTPUT:	op_pts[0] <= op_pts[0];
			default: 		op_pts[0] <= op_pts[0];
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n)	op_pts[1] <= 0;
	else begin
		case (current_state)
			STATE_IDLE,
			STATE_INPUT:	op_pts[1] <= 'd3;
			STATE_CALC: begin
				case (current_action)
					SHIFT_LEFT:		if (op_pts[1] != 'd0) op_pts[1] <= op_pts[1] - 1; else op_pts[1] <= op_pts[1];
					SHIFT_RIGHT:	if (op_pts[1] != 'd6) op_pts[1] <= op_pts[1] + 1; else op_pts[1] <= op_pts[1];
					default:		op_pts[1] <= op_pts[1];
				endcase
			end
			// STATE_OUTPUT:	op_pts[1] <= op_pts[1];
			default: 		op_pts[1] <= op_pts[1];
		endcase
	end
end

generate
	for (i=0; i<64; i=i+1) begin
		always @(posedge clk or negedge rst_n) begin
			if (!rst_n)	in_data_arr[i] <= 0;
			else begin
				case (current_state)
					STATE_IDLE,
					STATE_INPUT:	if (in_valid && (cnt == i)) in_data_arr[i] <= in_data;	else in_data_arr[i] <= in_data_arr[i];
					STATE_CALC: begin
						case (current_action)
							MIDPOINT: 					if (within_subregion[i]) in_data_arr[i] <= midpoint_value;		else in_data_arr[i] <= in_data_arr[i];
							AVERAGE: 					if (within_subregion[i]) in_data_arr[i] <= average_value;		else in_data_arr[i] <= in_data_arr[i];
							COUNTERCLOCKWISE_ROTATION: begin
								case (relative_location[i])
									UPPER_RIGHT:	in_data_arr[i] <= in_data_arr[(i+8 <= 63) ? i+8 : i];
									UPPER_LEFT:		in_data_arr[i] <= in_data_arr[(i+1 <= 63) ? i+1 : i];
									LOWER_LEFT:		in_data_arr[i] <= in_data_arr[(i-8 >=  0) ? i-8 : i];
									LOWER_RIGHT:	in_data_arr[i] <= in_data_arr[(i-1 >=  0) ? i-1 : i];
									default:		in_data_arr[i] <= in_data_arr[i];
								endcase
							end
							CLOCKWISE_ROTATION: begin
								case (relative_location[i])
									UPPER_RIGHT:	in_data_arr[i] <= in_data_arr[(i-1 >=  0) ? i-1 : i];
									UPPER_LEFT:		in_data_arr[i] <= in_data_arr[(i+8 <= 63) ? i+8 : i];
									LOWER_LEFT:		in_data_arr[i] <= in_data_arr[(i+1 <= 63) ? i+1 : i];
									LOWER_RIGHT:	in_data_arr[i] <= in_data_arr[(i-8 >=  0) ? i-8 : i];
									default:		in_data_arr[i] <= in_data_arr[i];
								endcase
							end
							FLIP: 						if (within_subregion[i]) in_data_arr[i] <= -in_data_arr[i];	else in_data_arr[i] <= in_data_arr[i];
							default:					in_data_arr[i] <= in_data_arr[i];
						endcase
					end
					// STATE_OUTPUT:	in_data_arr[i] <= in_data_arr[i];
					default:		in_data_arr[i] <= in_data_arr[i];
				endcase
			end
		end
	end
endgenerate

generate
	for (i=0; i<15; i=i+1) begin
		always @(posedge clk or negedge rst_n) begin
			if (!rst_n)							op_arr[i] <= 0;
			else if (in_valid && (cnt == i)) 	op_arr[i] <= op;
			else								op_arr[i] <= op_arr[i];
		end
	end
endgenerate

// calculation-related signals
generate
	for (i=0; i<64; i=i+1) begin
		assign within_subregion[i] = |(relative_location[i]);
	end
endgenerate

generate
	for (i=0; i<64; i=i+1) begin
		always @(*) begin
			relative_location[i] = {
				upper_right[i],
				upper_left[i],
				lower_left[i],
				lower_right[i]
			};
		end
	end
endgenerate

generate
	for (i=0; i<64; i=i+1) begin
		always @(*) begin
			if ((i/8 == op_pts[0] + 0) && (i%8 == op_pts[1] + 1))	upper_right[i] = 1;
			else													upper_right[i] = 0;
		end
	end
endgenerate

generate
	for (i=0; i<64; i=i+1) begin
		always @(*) begin
			if ((i/8 == op_pts[0] + 0) && (i%8 == op_pts[1] + 0))	upper_left[i] = 1;
			else													upper_left[i] = 0;
		end
	end
endgenerate

generate
	for (i=0; i<64; i=i+1) begin
		always @(*) begin
			if ((i/8 == op_pts[0] + 1) && (i%8 == op_pts[1] + 0))	lower_left[i] = 1;
			else													lower_left[i] = 0;
		end
	end
endgenerate

generate
	for (i=0; i<64; i=i+1) begin
		always @(*) begin
			if ((i/8 == op_pts[0] + 1) && (i%8 == op_pts[1] + 1))	lower_right[i] = 1;
			else													lower_right[i] = 0;
		end
	end
endgenerate

assign sub_region[0] = in_data_arr[{op_pts[0], op_pts[1]} + 1];
assign sub_region[1] = in_data_arr[{op_pts[0], op_pts[1]} + 0];
assign sub_region[2] = in_data_arr[{op_pts[0], op_pts[1]} + 8];
assign sub_region[3] = in_data_arr[{op_pts[0], op_pts[1]} + 9];

assign sort[0] = (sub_region[0] < sub_region[1]) ? sub_region[0] : sub_region[1];
assign sort[1] = (sub_region[0] < sub_region[1]) ? sub_region[1] : sub_region[0];

assign sort[2] = (sub_region[2] < sub_region[3]) ? sub_region[2] : sub_region[3];
assign sort[3] = (sub_region[2] < sub_region[3]) ? sub_region[3] : sub_region[2];

// assign sort[4] = (sort[0] < sort[2]) ? sort[0] : sort[2]; // min
// assign sort[5] = (sort[0] < sort[2]) ? sort[2] : sort[0];

// assign sort[6] = (sort[1] < sort[3]) ? sort[1] : sort[3];
// assign sort[7] = (sort[1] < sort[3]) ? sort[3] : sort[1]; // max

assign sort[4] = (sort[0] < sort[2]) ? sort[2] : sort[0];
assign sort[5] = (sort[1] < sort[3]) ? sort[1] : sort[3];

assign midpoint_value = (sort[4] + sort[5]) / 2;
assign average_value = (sub_region[0] + sub_region[1] + sub_region[2] + sub_region[3]) / 4;
endmodule // IDC