module NN(
	// Input signals
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
	// Output signals
	out_valid,
	out
);

//==================PARAMETER=====================//
// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 1;
parameter inst_arch = 2;

parameter STATE_IDLE = 3'd0;
parameter STATE_BREAK_OPT = 3'd1;
parameter STATE_IMG = 3'd2;
parameter STATE_BREAK_IMG = 3'd3;
parameter STATE_KER = 3'd4;
parameter STATE_BREAK_KER = 3'd5;
parameter STATE_CALC = 3'd6;
parameter STATE_OUTPUT = 3'd7;

parameter SYSTOLIC_REPEAT = 12-1; // reapeat 12 times w different input dataflow & kernel weight
parameter SYSTOLIC_CYCLE = 34; // cycle starting from 0 to 33
parameter ACTV_CYCLE = 5;
// cycle 0	-->	in
// cycle 1	-->	mult_out / exp_out
// cycle 2	-->	cmp_out / addsub_out
// cycle 3	--> cmp_out_buf / div_out
// cycle 4	--> actv_out
// cycle 5	--> out

integer i,j,k;
genvar x,y,z;

//=========INPUT AND OUTPUT DECLARATION==============//
input  clk, rst_n, in_valid_i, in_valid_k, in_valid_o;
input [inst_sig_width+inst_exp_width:0] Image1, Image2, Image3;
input [inst_sig_width+inst_exp_width:0] Kernel1, Kernel2, Kernel3;
input [1:0] Opt;
output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

//==================Wire & Register===================//
reg [2:0] current_state, next_state; // FSM
reg [6:0] cnt, calc_cnt;

reg [1:0] opt_val;
reg [inst_sig_width+inst_exp_width:0] img_arr[35:0][2:0], img_arr_center[15:0][2:0]; // img_size x #img
reg [inst_sig_width+inst_exp_width:0] ker_arr[8:0][3:0][2:0]; // ker_size x #ker_per_img x #img

reg [inst_sig_width+inst_exp_width:0] result_arr[15:0][3:0]; // img_size x #ker

// systolic array
reg [inst_sig_width+inst_exp_width:0] a_in_0[0:0]; // input buffer
reg [inst_sig_width+inst_exp_width:0] a_in_1[1:0];
reg [inst_sig_width+inst_exp_width:0] a_in_2[2:0];
reg [inst_sig_width+inst_exp_width:0] a_in_3[3:0];
reg [inst_sig_width+inst_exp_width:0] a_in_4[4:0];
reg [inst_sig_width+inst_exp_width:0] a_in_5[5:0];
reg [inst_sig_width+inst_exp_width:0] a_in_6[6:0];
reg [inst_sig_width+inst_exp_width:0] a_in_7[7:0];
reg [inst_sig_width+inst_exp_width:0] a_in_8[8:0];

reg [inst_sig_width+inst_exp_width:0] head_c_in; // PE weight / mac signal
reg load_weight;
wire [inst_sig_width+inst_exp_width:0] z_out[8:0]; // PE z_out signal
reg [inst_sig_width+inst_exp_width:0] z_out_buf[7:0];

reg [inst_sig_width+inst_exp_width:0] adder_a_in, adder_b_in; // adder signal
wire [inst_sig_width+inst_exp_width:0] adder_z_out;

wire [inst_sig_width+inst_exp_width:0] shuffled_arr[63:0];
reg [inst_sig_width+inst_exp_width:0] actv_in;
wire [inst_sig_width+inst_exp_width:0] actv_out;

//==================Design===================//
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
            STATE_IDLE: begin // idle & read opt signal
                if (in_valid_o) next_state = STATE_BREAK_OPT;
                else next_state = current_state;
            end
			STATE_BREAK_OPT: begin // idle for 2 cycles
                if (cnt==1) next_state = STATE_IMG;
                else next_state = current_state;
			end
            STATE_IMG: begin
                if (cnt==15) next_state = STATE_BREAK_IMG;
                else next_state = current_state;
            end
			STATE_BREAK_IMG: begin // idle for 2 cycles
                if (cnt==1) next_state = STATE_KER;
                else next_state = current_state;
			end
			STATE_KER: begin
				if (cnt==35) next_state = STATE_BREAK_KER; 
				else next_state = current_state;
			end
			STATE_BREAK_KER: begin
				next_state = STATE_CALC;
			end
            STATE_CALC: begin
                if ((cnt==SYSTOLIC_REPEAT) && (calc_cnt==SYSTOLIC_CYCLE)) next_state = STATE_OUTPUT;
                else next_state = current_state;
            end
            STATE_OUTPUT: begin
                if (cnt==(63+ACTV_CYCLE)) next_state = STATE_IDLE;
                else next_state = current_state;
            end
            default: next_state = current_state;
        endcase
    end
end

// output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 0;
        out <= 0;
    end
	else if ((current_state==STATE_OUTPUT) && (cnt>=ACTV_CYCLE)) begin
		out_valid <= 1;
		out <= actv_out;
	end
	else begin
		out_valid <= 0;
		out <= 0;
	end
end

// counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 0;
    else begin
        case (current_state)
            STATE_IDLE: cnt <= 0;
			STATE_BREAK_OPT: begin
				if (cnt==1) cnt <= 0;
				else cnt <= cnt + 1;
			end 
			STATE_IMG: begin
				if (cnt==15) cnt <= 0;
				else cnt <= cnt + 1;
			end 
			STATE_BREAK_IMG: begin
				if (cnt==1) cnt <= 0;
				else cnt <= cnt + 1;
			end
			STATE_KER: begin
				if (cnt==35) cnt <= 0;
				else cnt <= cnt + 1;
			end
			STATE_BREAK_KER: cnt <= 0;
			STATE_CALC: begin
				if (calc_cnt == SYSTOLIC_CYCLE) begin
					if (cnt == SYSTOLIC_REPEAT) cnt <= 0;
					else cnt <= cnt + 1;
				end
				else cnt <= cnt;
			end
			STATE_OUTPUT: begin
				if (cnt==(63+ACTV_CYCLE)) cnt <= 0;
				else cnt <= cnt + 1;
			end 
            default: cnt <= 0;
        endcase
    end
end

// sub-counter information
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) calc_cnt <= 0;
	else if ((current_state == STATE_CALC) && (calc_cnt != SYSTOLIC_CYCLE)) begin
		calc_cnt <= calc_cnt + 1;
	end
	else calc_cnt <= 0;
end

// read opt data
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		opt_val <= 0;
	end
	else if (in_valid_o) opt_val <= Opt;
	else opt_val <= opt_val;
end

// read image data
// 0	1	2	3	4	5
// 6	7	8	9	10	11
// 12	13	14	15	16	17
// 18	19	20	21	22	23
// 24	25	26	27	28	29
// 30	31	32	33	34	35
// img_arr[35:0][2:0]; // img_size x #img

// corner value
always @(*) begin // padding
	for (i=0;i<3;i=i+1) begin
		// left top
		img_arr[0][i] = (opt_val[1]) ? 0 : img_arr[7][i];
		img_arr[1][i] = (opt_val[1]) ? 0 : img_arr[7][i];
		img_arr[6][i] = (opt_val[1]) ? 0 : img_arr[7][i];
		// right top
		img_arr[4][i] = (opt_val[1]) ? 0 : img_arr[10][i];
		img_arr[5][i] = (opt_val[1]) ? 0 : img_arr[10][i];
		img_arr[11][i] = (opt_val[1]) ? 0 : img_arr[10][i];
		// left bot
		img_arr[24][i] = (opt_val[1]) ? 0 : img_arr[25][i];
		img_arr[30][i] = (opt_val[1]) ? 0 : img_arr[25][i];
		img_arr[31][i] = (opt_val[1]) ? 0 : img_arr[25][i];
		// right bot
		img_arr[29][i] = (opt_val[1]) ? 0 : img_arr[28][i];
		img_arr[34][i] = (opt_val[1]) ? 0 : img_arr[28][i];
		img_arr[35][i] = (opt_val[1]) ? 0 : img_arr[28][i];
		// top
		img_arr[2][i] = (opt_val[1]) ? 0 : img_arr[8][i];
		img_arr[3][i] = (opt_val[1]) ? 0 : img_arr[9][i];
		// left
		img_arr[12][i] = (opt_val[1]) ? 0 : img_arr[13][i];
		img_arr[18][i] = (opt_val[1]) ? 0 : img_arr[19][i];
		// right
		img_arr[17][i] = (opt_val[1]) ? 0 : img_arr[16][i];
		img_arr[23][i] = (opt_val[1]) ? 0 : img_arr[22][i];
		// bot
		img_arr[32][i] = (opt_val[1]) ? 0 : img_arr[26][i];
		img_arr[33][i] = (opt_val[1]) ? 0 : img_arr[27][i];
	end
end

// center value
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i=0;i<3;i=i+1) begin
			for (j=0;j<16;j=j+1) begin
				img_arr_center[j][i] <= 0;
			end
		end
	end
	else if (in_valid_i) begin
		img_arr_center[cnt][0] <= Image1;
		img_arr_center[cnt][1] <= Image2;
		img_arr_center[cnt][2] <= Image3;
	end
	else begin
		for (i=0;i<3;i=i+1) begin
			for (j=0;j<16;j=j+1) begin
				img_arr_center[j][i] <= img_arr_center[j][i];
			end
		end
	end
end

always @(*) begin
	for (i=0;i<3;i=i+1) begin
		img_arr[ 7][i] = img_arr_center[ 0][i];
		img_arr[ 8][i] = img_arr_center[ 1][i];
		img_arr[ 9][i] = img_arr_center[ 2][i];
		img_arr[10][i] = img_arr_center[ 3][i];

		img_arr[13][i] = img_arr_center[ 4][i];
		img_arr[14][i] = img_arr_center[ 5][i];
		img_arr[15][i] = img_arr_center[ 6][i];
		img_arr[16][i] = img_arr_center[ 7][i];

		img_arr[19][i] = img_arr_center[ 8][i];
		img_arr[20][i] = img_arr_center[ 9][i];
		img_arr[21][i] = img_arr_center[10][i];
		img_arr[22][i] = img_arr_center[11][i];

		img_arr[25][i] = img_arr_center[12][i];
		img_arr[26][i] = img_arr_center[13][i];
		img_arr[27][i] = img_arr_center[14][i];
		img_arr[28][i] = img_arr_center[15][i];

	end
end

// read kernel data
// 0	1	2
// 3	4	5
// 6	7	8
// ker_arr[8:0][3:0][2:0]; // ker_size x #ker_per_img x #img
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i=0;i<3;i=i+1) begin
			for (j=0;j<4;j=j+1) begin
				for (k=0;k<9;k=k+1) begin
					ker_arr[k][j][i] <= 0;
				end
			end
		end
	end
	else if (in_valid_k) begin
		ker_arr[cnt%9][cnt/9][0] <= Kernel1;
		ker_arr[cnt%9][cnt/9][1] <= Kernel2;
		ker_arr[cnt%9][cnt/9][2] <= Kernel3;
	end
	else begin
		for (i=0;i<3;i=i+1) begin
			for (j=0;j<4;j=j+1) begin
				for (k=0;k<9;k=k+1) begin
					ker_arr[k][j][i] <= ker_arr[k][j][i];
				end
			end
		end
	end
end

// convolution result
// 1	2	3	4	5	6
// 7	8	9	10	11	12
// 13	14	15	16	17	18
// 19	20	21	22	23	24
// 25	26	27	28	29	30
// 31	32	33	34	35	36
// reg [inst_sig_width+inst_exp_width:0] result_arr[15:0][3:0]; // img_size x #ker
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i=0;i<16;i=i+1) begin
			for (j=0;j<4;j=j+1) begin
				result_arr[i][j] <= 0;
			end
		end
	end
	else if (current_state==STATE_IDLE) begin
		for (i=0;i<16;i=i+1) begin
			for (j=0;j<4;j=j+1) begin
				result_arr[i][j] <= 0;
			end
		end
	end
	else if ((current_state==STATE_CALC) && (calc_cnt>=19)) begin
		result_arr[calc_cnt-19][cnt%4] <= adder_z_out;
	end
	else begin
		for (i=0;i<16;i=i+1) begin
			for (j=0;j<4;j=j+1) begin
				result_arr[i][j] <= result_arr[i][j];
			end
		end
	end
end


// Dataflow within systolic array (parralel with 4 channels)
// Cycle	Operation of Process Unit
// 0		Load 9th kernel weight
// 1		Load 8th kernel weight
// 2		Load 7th kernel weight
// 3		Load 6th kernel weight
// 4		Load 5th kernel weight
// 5		Load 4th kernel weight
// 6		Load 3rd kernel weight
// 7		Load 2nd kernel weight
// 8		Load 1st kernel weight
// 9		Calculate  1st component of  1st conv value
// 10		Calculate  2nd component of  1st conv value
// 11		Calculate  3rd component of  1st conv value
// 12		Calculate  4th component of  1st conv value
// 13		Calculate  5th component of  1st conv value
// 14		Calculate  6th component of  1st conv value
// 15		Calculate  7th component of  1st conv value
// 16		Calculate  8th component of  1st conv value
// 17		Calculate  9th component of  1st conv value
// 18		Add up 1st conv value with original value
// 19		Store the value corresponding to  1st conv value back to array
// 20		Store the value corresponding to  2nd conv value back to array
// 21		Store the value corresponding to  3rd conv value back to array
// 22		Store the value corresponding to  4th conv value back to array
// 23		Store the value corresponding to  5th conv value back to array
// 24		Store the value corresponding to  6th conv value back to array
// 25		Store the value corresponding to  7th conv value back to array	
// 26		Store the value corresponding to  8th conv value back to array
// 27		Store the value corresponding to  9th conv value back to array
// 28		Store the value corresponding to 10th conv value back to array
// 29		Store the value corresponding to 11th conv value back to array
// 30		Store the value corresponding to 12th conv value back to array
// 31		Store the value corresponding to 13th conv value back to array
// 32		Store the value corresponding to 14th conv value back to array
// 33		Store the value corresponding to 15th conv value back to array
// 34		Store the value corresponding to 16th conv value back to array

// Repeat	3 * 4 = 12 times
//  0		Image 1 & Kernel 1
//  1		Image 1 & Kernel 2
//  2		Image 1 & Kernel 3
//  3		Image 1 & Kernel 4
//  4		Image 2 & Kernel 1
//  5		Image 2 & Kernel 2
//  6		Image 2 & Kernel 3
//  7		Image 2 & Kernel 4
//  8		Image 3 & Kernel 1
//  9		Image 3 & Kernel 2
// 10		Image 3 & Kernel 3
// 11		Image 3 & Kernel 4

// a_in_0	 								0
// a_in_1	 							0	1
// a_in_2	 						0	1	2
// a_in_3	 					0	1	2	3
// a_in_4	 				0	1	2	3	4
// a_in_5	 			0	1	2	3	4	5
// a_in_6	 		0	1	2	3	4	5	6
// a_in_7	 	0	1	2	3	4	5	6	7
// a_in_8	 0	1	2	3	4	5	6	7	8

// 1 set of systolic array pipelined wtih 9 process unit and one adder
PE PE0( .clk(clk),	.a_in(a_in_0[0]),	.load_w(load_weight),	.c_in(head_c_in),		.z_out(z_out[0]));
PE PE1( .clk(clk),	.a_in(a_in_1[1]),	.load_w(load_weight),	.c_in(z_out_buf[0]),	.z_out(z_out[1]));
PE PE2( .clk(clk),	.a_in(a_in_2[2]),	.load_w(load_weight),	.c_in(z_out_buf[1]),	.z_out(z_out[2]));
PE PE3( .clk(clk),	.a_in(a_in_3[3]),	.load_w(load_weight),	.c_in(z_out_buf[2]),	.z_out(z_out[3]));
PE PE4( .clk(clk),	.a_in(a_in_4[4]),	.load_w(load_weight),	.c_in(z_out_buf[3]),	.z_out(z_out[4]));
PE PE5( .clk(clk),	.a_in(a_in_5[5]),	.load_w(load_weight),	.c_in(z_out_buf[4]),	.z_out(z_out[5]));
PE PE6( .clk(clk),	.a_in(a_in_6[6]),	.load_w(load_weight),	.c_in(z_out_buf[5]),	.z_out(z_out[6]));
PE PE7( .clk(clk),	.a_in(a_in_7[7]),	.load_w(load_weight),	.c_in(z_out_buf[6]),	.z_out(z_out[7]));
PE PE8( .clk(clk), 	.a_in(a_in_8[8]),	.load_w(load_weight),	.c_in(z_out_buf[7]),	.z_out(z_out[8]));

ADDER ADDER0( .clk(clk), .a_in(adder_a_in), .b_in(adder_b_in), .z_out(adder_z_out));

// input buffer of systolic array
//		cycle		-->		index of a_in_0[0]
//  9	10	11	12	-->		 0	 1	 2	 3
// 13	14	15	16	-->		 6	 7	 8	 9
// 17	18	19	20	-->		12	13	14	15
// 21	22	23	24	-->		18	19	20	21
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		a_in_0[0] <= 0;
		a_in_1[0] <= 0;
		a_in_2[0] <= 0;
		a_in_3[0] <= 0;
		a_in_4[0] <= 0;
		a_in_5[0] <= 0;
		a_in_6[0] <= 0;
		a_in_7[0] <= 0;
		a_in_8[0] <= 0;
	end
	else if ((current_state==STATE_CALC) && (calc_cnt>=9) && (calc_cnt<=9+16-1)) begin
		a_in_0[0] <= img_arr[((calc_cnt-9)/4 + 0) * 6 + ((calc_cnt-9)%4 + 0)][cnt/4];
		a_in_1[0] <= img_arr[((calc_cnt-9)/4 + 0) * 6 + ((calc_cnt-9)%4 + 1)][cnt/4];
		a_in_2[0] <= img_arr[((calc_cnt-9)/4 + 0) * 6 + ((calc_cnt-9)%4 + 2)][cnt/4];
		a_in_3[0] <= img_arr[((calc_cnt-9)/4 + 1) * 6 + ((calc_cnt-9)%4 + 0)][cnt/4];
		a_in_4[0] <= img_arr[((calc_cnt-9)/4 + 1) * 6 + ((calc_cnt-9)%4 + 1)][cnt/4];
		a_in_5[0] <= img_arr[((calc_cnt-9)/4 + 1) * 6 + ((calc_cnt-9)%4 + 2)][cnt/4];
		a_in_6[0] <= img_arr[((calc_cnt-9)/4 + 2) * 6 + ((calc_cnt-9)%4 + 0)][cnt/4];
		a_in_7[0] <= img_arr[((calc_cnt-9)/4 + 2) * 6 + ((calc_cnt-9)%4 + 1)][cnt/4];
		a_in_8[0] <= img_arr[((calc_cnt-9)/4 + 2) * 6 + ((calc_cnt-9)%4 + 2)][cnt/4];
	end
	else begin
		a_in_0[0] <= 0;
		a_in_1[0] <= 0;
		a_in_2[0] <= 0;
		a_in_3[0] <= 0;
		a_in_4[0] <= 0;
		a_in_5[0] <= 0;
		a_in_6[0] <= 0;
		a_in_7[0] <= 0;
		a_in_8[0] <= 0;
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i=1;i<2;i=i+1) a_in_1[i] <= 0;
		for (i=1;i<3;i=i+1) a_in_2[i] <= 0;
		for (i=1;i<4;i=i+1) a_in_3[i] <= 0;
		for (i=1;i<5;i=i+1) a_in_4[i] <= 0;
		for (i=1;i<6;i=i+1) a_in_5[i] <= 0;
		for (i=1;i<7;i=i+1) a_in_6[i] <= 0;
		for (i=1;i<8;i=i+1) a_in_7[i] <= 0;
		for (i=1;i<9;i=i+1) a_in_8[i] <= 0;
	end
	else begin
		for (i=1;i<2;i=i+1) a_in_1[i] <= a_in_1[i-1];
		for (i=1;i<3;i=i+1) a_in_2[i] <= a_in_2[i-1];
		for (i=1;i<4;i=i+1) a_in_3[i] <= a_in_3[i-1];
		for (i=1;i<5;i=i+1) a_in_4[i] <= a_in_4[i-1];
		for (i=1;i<6;i=i+1) a_in_5[i] <= a_in_5[i-1];
		for (i=1;i<7;i=i+1) a_in_6[i] <= a_in_6[i-1];
		for (i=1;i<8;i=i+1) a_in_7[i] <= a_in_7[i-1];
		for (i=1;i<9;i=i+1) a_in_8[i] <= a_in_8[i-1];
	end

end

// load_weight ? load weight to PE & pass out the weight : normal MAC operation
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) load_weight <= 0;
	else if (calc_cnt<9) load_weight <= 1;
	else load_weight <= 0;
end

// load_weight ? weight : c_signal of MAC
always @(posedge clk or negedge rst_n) begin
	// ker_arr[8:0][3:0][2:0]
	if (!rst_n) head_c_in <= 0;
	else if (calc_cnt<=8) head_c_in <= ker_arr[8-calc_cnt][cnt%4][cnt/4];
	else head_c_in <= 0;
end

// buffer for PE output
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i=0;i<8;i=i+1) z_out_buf[i] <= 0;
	end
	else begin
		for (i=0;i<8;i=i+1) z_out_buf[i] <= z_out[i];
	end
end

// result = result + conv value
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) adder_a_in <= 0;
	else if ((current_state==STATE_CALC) && (calc_cnt>=18) && ((calc_cnt<=33))) begin
		adder_a_in <= result_arr[calc_cnt-18][cnt%4];
	end
	else adder_a_in <= 0;
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) adder_b_in <= 0;
	else adder_b_in <= z_out[8];
end

// reshuffle array
// reg [inst_sig_width+inst_exp_width:0] result_arr[15:0][3:0]; // img_size x #ker
generate
  for (x=0; x<64; x=x+1) begin
	  assign shuffled_arr[ x] = result_arr[x/16*4 + x%16%8/2][x%16/8*2 + x%16%8%2];
  end
endgenerate

// assign shuffled_arr[ 0] = result_arr[ 0][0];
// assign shuffled_arr[ 1] = result_arr[ 0][1];
// assign shuffled_arr[ 2] = result_arr[ 1][0];
// assign shuffled_arr[ 3] = result_arr[ 1][1];
// assign shuffled_arr[ 4] = result_arr[ 2][0];
// assign shuffled_arr[ 5] = result_arr[ 2][1];
// assign shuffled_arr[ 6] = result_arr[ 3][0];
// assign shuffled_arr[ 7] = result_arr[ 3][1];
// assign shuffled_arr[ 8] = result_arr[ 0][2];
// assign shuffled_arr[ 9] = result_arr[ 0][3];
// assign shuffled_arr[10] = result_arr[ 1][2];
// assign shuffled_arr[11] = result_arr[ 1][3];
// assign shuffled_arr[12] = result_arr[ 2][2];
// assign shuffled_arr[13] = result_arr[ 2][3];
// assign shuffled_arr[14] = result_arr[ 3][2];
// assign shuffled_arr[15] = result_arr[ 3][3];

// assign shuffled_arr[16] = result_arr[ 4][0];
// assign shuffled_arr[17] = result_arr[ 4][1];
// assign shuffled_arr[18] = result_arr[ 5][0];
// assign shuffled_arr[19] = result_arr[ 5][1];
// assign shuffled_arr[20] = result_arr[ 6][0];
// assign shuffled_arr[21] = result_arr[ 6][1];
// assign shuffled_arr[22] = result_arr[ 7][0];
// assign shuffled_arr[23] = result_arr[ 7][1];
// assign shuffled_arr[24] = result_arr[ 4][2];
// assign shuffled_arr[25] = result_arr[ 4][3];
// assign shuffled_arr[26] = result_arr[ 5][2];
// assign shuffled_arr[27] = result_arr[ 5][3];
// assign shuffled_arr[28] = result_arr[ 6][2];
// assign shuffled_arr[29] = result_arr[ 6][3];
// assign shuffled_arr[30] = result_arr[ 7][2];
// assign shuffled_arr[31] = result_arr[ 7][3];

// assign shuffled_arr[32] = result_arr[ 8][0];
// assign shuffled_arr[33] = result_arr[ 8][1];
// assign shuffled_arr[34] = result_arr[ 9][0];
// assign shuffled_arr[35] = result_arr[ 9][1];
// assign shuffled_arr[36] = result_arr[10][0];
// assign shuffled_arr[37] = result_arr[10][1];
// assign shuffled_arr[38] = result_arr[11][0];
// assign shuffled_arr[39] = result_arr[11][1];
// assign shuffled_arr[40] = result_arr[ 8][2];
// assign shuffled_arr[41] = result_arr[ 8][3];
// assign shuffled_arr[42] = result_arr[ 9][2];
// assign shuffled_arr[43] = result_arr[ 9][3];
// assign shuffled_arr[44] = result_arr[10][2];
// assign shuffled_arr[45] = result_arr[10][3];
// assign shuffled_arr[46] = result_arr[11][2];
// assign shuffled_arr[47] = result_arr[11][3];

// assign shuffled_arr[48] = result_arr[12][0];
// assign shuffled_arr[49] = result_arr[12][1];
// assign shuffled_arr[50] = result_arr[13][0];
// assign shuffled_arr[51] = result_arr[13][1];
// assign shuffled_arr[52] = result_arr[14][0];
// assign shuffled_arr[53] = result_arr[14][1];
// assign shuffled_arr[54] = result_arr[15][0];
// assign shuffled_arr[55] = result_arr[15][1];
// assign shuffled_arr[56] = result_arr[12][2];
// assign shuffled_arr[57] = result_arr[12][3];
// assign shuffled_arr[58] = result_arr[13][2];
// assign shuffled_arr[59] = result_arr[13][3];
// assign shuffled_arr[60] = result_arr[14][2];
// assign shuffled_arr[61] = result_arr[14][3];
// assign shuffled_arr[62] = result_arr[15][2];
// assign shuffled_arr[63] = result_arr[15][3];

ACTV ACTV_CELL( .clk(clk), .actv_sig(opt_val), .in(actv_in), .out(actv_out));

always @(posedge clk) begin
	if ((current_state==STATE_OUTPUT) && (cnt<=63)) actv_in <= shuffled_arr[cnt];
	else actv_in <= 0;
end

endmodule

// process unit cell
module PE(
	// Input signals
	clk,
	a_in,
	load_w,
	c_in,
	// Output signals
	z_out,
);

//==================PARAMETER=====================//
// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 1;
// parameter inst_arch = 2;

//=========INPUT AND OUTPUT DECLARATION==============//
input  clk, load_w;
input [inst_sig_width+inst_exp_width:0] a_in, c_in;
output reg [inst_sig_width+inst_exp_width:0] z_out;
//==================Wire & Register===================//
wire [inst_sig_width+inst_exp_width:0] mac_z;
reg [inst_sig_width+inst_exp_width:0] weight;

//==================Design===================//
// if load_w is 1, then load the weight		--> weig = c_in, z_out = c_in
// if load_w is 0, then do MAC operation 	--> weig = weig, z_out = aw+c

always @(posedge clk) begin
	if (load_w) weight <= c_in;
	else weight <= weight;
end

always @(*) begin
	z_out = (!load_w) ? mac_z : c_in;
end

DW_fp_mac # (inst_sig_width, inst_exp_width, inst_ieee_compliance) U1(
	.a(a_in),
	.b(weight),
	.c(c_in),
	.rnd(3'b000),
	.z(mac_z),
	.status()
);

// synopsys dc_script_begin
// set_implementation rtl U1
// synopsys dc_script_end

endmodule

module ADDER(
	// Input signals
	clk,
	a_in,
	b_in,
	// Output signals
	z_out,
);

//==================PARAMETER=====================//
// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 1;
// parameter inst_arch = 2;

//=========INPUT AND OUTPUT DECLARATION==============//
input  clk;
input [inst_sig_width+inst_exp_width:0] a_in, b_in;
output reg [inst_sig_width+inst_exp_width:0] z_out;

//==================Wire & Register===================//
wire [inst_sig_width+inst_exp_width:0] a_plus_b;

//==================Design===================//
// if pass is 1, then output a+b
// if pass is 0, then output zero

always @(*) begin
	z_out = a_plus_b;
end

DW_fp_add # (inst_sig_width, inst_exp_width, inst_ieee_compliance) U1(
	.a(a_in),
	.b(b_in),
	.rnd(3'b000),
	.z(a_plus_b),
	.status()
);

// synopsys dc_script_begin
// set_implementation rtl U1
// synopsys dc_script_end
endmodule

module ACTV(
	clk,
	actv_sig,
	in,
	out
);

//==================PARAMETER=====================//
// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 1;
parameter inst_arch = 1; // speed optimization

parameter inst_faithful_round = 0;

//=========INPUT AND OUTPUT DECLARATION==============//
input clk;
input [1:0] actv_sig;
input [inst_sig_width+inst_exp_width:0] in;
output reg [inst_sig_width+inst_exp_width:0] out;

//==================Wire & Register===================//
// reg [inst_sig_width+inst_exp_width:0] fp_cmp_out_buf[3:0];
reg [inst_sig_width+inst_exp_width:0] mult_in_a, mult_in_b;
wire [inst_sig_width+inst_exp_width:0] mult_out;

reg [inst_sig_width+inst_exp_width:0] cmp_in_a, cmp_in_b;
reg [inst_sig_width+inst_exp_width:0] cmp_out_buf;
// wire [inst_sig_width+inst_exp_width:0] cmp_out;
reg [inst_sig_width+inst_exp_width:0] cmp_out;

reg [inst_sig_width+inst_exp_width:0] exp_in_p, exp_in_n;
wire [inst_sig_width+inst_exp_width:0] exp_out_p, exp_out_n;

reg [inst_sig_width+inst_exp_width:0] addsub_in_a_p, addsub_in_b_p;
reg [inst_sig_width+inst_exp_width:0] addsub_in_a_m, addsub_in_b_m;
wire [inst_sig_width+inst_exp_width:0] addsub_out_p, addsub_out_m;

reg [inst_sig_width+inst_exp_width:0] div_in_n, div_in_d;
wire [inst_sig_width+inst_exp_width:0] div_out;

// Activation Signal
// 0	Relu = max(0,x)
// 1	Leaky_Relu = max(0.1x,x)
// 2	Sigmoid = 1 / (1 + e^(-x))
// 3	Tanh = (e^(x) - e^(-x)) / (e^(x) + e^(-x))

// Relu / LeakyRelu
// in,actv_sig		-->	mult_in_{a,b}			-->	FP_MULT		-->	mult_out
// mult_out			-->	cmp_out													(mult_out			-->	cmp_in_{a,b}			-->	FP_CMP		-->	cmp_out)
// cmp_out			-->	cmp_out_buf

// Sigmoid / Tanh
// in,actv_sig		-->	exp_in_{p,n}			-->	FP_EXP		-->	exp_out_{p,n}
// exp_out			-->	addsub_in_{a,b}_{p,m}	-->	FP_ADDSUB	-->	addsub_out_{p,m}
// addsub_out_{p,m}	-->	div_in_{n,d}			-->	FP_DIV		-->	div_out

// T0
always @(posedge clk) begin
	mult_in_a <= 32'h3dcccccd; // 0.1
	mult_in_b <= in;
end

always @(posedge clk) begin
	exp_in_p <= { in[31],in[30:0]}; // x
	exp_in_n <= {~in[31],in[30:0]}; // -x
end

DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance) MULT_PTONE(
	.a(mult_in_a),
	.b(mult_in_b),
	.rnd(3'b000),
	.z(mult_out), // 0.1x
	.status()
);

DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) EXPP(
	.a(exp_in_p),
	.z(exp_out_p), // e^x
	.status()
);

DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) EXPN(
	.a(exp_in_n),
	.z(exp_out_n), // e^(-x)
	.status()
);


// T1
always @(posedge clk) begin
	if (actv_sig==0) cmp_out <= mult_in_b[31] ? 0 : mult_in_b; // Relu, neg ? 0 : valu
	else cmp_out <= mult_in_b[31] ? mult_out : mult_in_b; // LeakyRelu, neg ? 0.1x : x
end

always @(posedge clk) begin
	addsub_in_a_m <= exp_out_p; // e^x
	addsub_in_b_m <= exp_out_n; // e^(-x)
end

always @(posedge clk) begin
	addsub_in_a_p <= (actv_sig==3) ? exp_out_p : 32'h3f800000; // Tanh ? e^x : 1
	addsub_in_b_p <= exp_out_n; // e^(-x)
end

DW_fp_addsub #(inst_sig_width, inst_exp_width, inst_ieee_compliance) ADD(
	.a(addsub_in_a_p),
	.b(addsub_in_b_p),
	.rnd(3'b000),
	.op(1'b0),
	.z(addsub_out_p), // Sigmoid: 1 + e^(-x), Tanh: e^x + e^(-x)
	.status()
);

DW_fp_addsub #(inst_sig_width, inst_exp_width, inst_ieee_compliance) SUB(
	.a(addsub_in_a_m),
	.b(addsub_in_b_m),
	.rnd(3'b000),
	.op(1'b1),
	.z(addsub_out_m), // e^x - e^(-x)
	.status()
);

// T2
always @(posedge clk) begin
	cmp_out_buf <= cmp_out;
end

always @(posedge clk) begin
	div_in_n <= (actv_sig==3) ? addsub_out_m : 32'h3f800000; // Sigmoid: 1, Tanh: e^x - e^(-x)
	div_in_d <= addsub_out_p; // Sigmoid: 1 + e^(-x), Tanh: e^x + e^(-x)
end

DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_faithful_round) DIV(
	.a(div_in_n),
	.b(div_in_d),
	.rnd(3'b000),
	.z(div_out),
	.status()
);

// T3
always @(posedge clk) begin
	out <= (actv_sig[1]) ? div_out : cmp_out_buf;
end

// synopsys dc_script_begin
// set_implementation rtl MULT_PTONE
// set_implementation rtl EXPP
// set_implementation rtl EXPN
// set_implementation rtl ADD
// set_implementation rtl SUB
// set_implementation rtl DIV
// synopsys dc_script_end

endmodule