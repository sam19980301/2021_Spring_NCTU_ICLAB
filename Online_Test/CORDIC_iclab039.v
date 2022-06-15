module	CORDIC (
	input	wire				clk, rst_n, in_valid,
	input	wire	signed	[11:0]	in_x, in_y,
	output	reg		[11:0]	out_mag,
	output	reg		[20:0]	out_phase,
	output	reg					out_valid

	);

// input_x and input_y -> 1'b sign , 3'b int , 8'b fraction
// out_mag -> 4b int , 8'b fraction
// output -> 1'b int , 20'b fraction 
wire	[20:0]	cordic_angle [0:17];
wire  [14:0]	Constant;

// FSM
reg [1:0] current_state, next_state;
reg [9:0] cnt;
reg [4:0] subcnt;
reg [9:0] n_input;

// SRAM & Register Memory
wire signed [11:0]   mag_mem_q;
reg                  mag_mem_wen;
reg [9:0]            mag_mem_addr;
reg [11:0]           mag_mem_data;

wire [20:0]   phase_mem_q;
reg           phase_mem_wen;
reg [9:0]     phase_mem_addr;
reg [20:0]    phase_mem_data;


// CORDIC Algorithm
reg signed [23:0] x_val[18:0];
reg signed [23:0] y_val[18:0];
reg signed [21:0] z_val[18:0];
reg [26:0] mag_val_precise;
reg [20:0] pha_val;

// Main Calculation
// Cycle    Operation
//  0       Get rotation
//  0       Get  1st iteration
//  1       Get  2nd itertaion
// ...
// 17       Get 18th iteration
// 18       Get magnitude
// 19       Set write signal

// Output
// Cycle    Posedge clk
//  0       Set read signal
//  1       Idle          
//  2       Output 1st answer
// ...
// n+1      Output nth answer

//==================PARAMETER=====================//
parameter STATE_IDLE =  2'd0;
parameter STATE_INPUT = 2'd1;
parameter STATE_OUT =   2'd3;

integer i;

//cordic angle -> 1'b int, 20'b fraciton
assign   cordic_angle[ 0] = 21'h04_0000; //  45        deg
assign   cordic_angle[ 1] = 21'h02_5c81; //  26.565051 deg
assign   cordic_angle[ 2] = 21'h01_3f67; //  14.036243 deg
assign   cordic_angle[ 3] = 21'h00_a222; //   7.125016 deg
assign   cordic_angle[ 4] = 21'h00_5162; //   3.576334 deg
assign   cordic_angle[ 5] = 21'h00_28bb; //   1.789911 deg
assign   cordic_angle[ 6] = 21'h00_145f; //   0.895174 deg
assign   cordic_angle[ 7] = 21'h00_0a30; //   0.447614 deg
assign   cordic_angle[ 8] = 21'h00_0518; //   0.223811 deg
assign   cordic_angle[ 9] = 21'h00_028b; //   0.111906 deg
assign   cordic_angle[10] = 21'h00_0146; //   0.055953 deg
assign   cordic_angle[11] = 21'h00_00a3; //   0.027976 deg
assign   cordic_angle[12] = 21'h00_0051; //   0.013988 deg
assign   cordic_angle[13] = 21'h00_0029; //   0.006994 deg
assign   cordic_angle[14] = 21'h00_0014; //   0.003497 deg
assign   cordic_angle[15] = 21'h00_000a; //   0.001749 deg
assign   cordic_angle[16] = 21'h00_0005; //   0.000874 deg
assign   cordic_angle[17] = 21'h00_0003; //   0.000437 deg
   
//Constant-> 1'b int, 14'b fraction
assign  Constant = {1'b0,14'b10011011011101}; // 1/K = 0.6072387695

//==================Design===================//
// state FSM
// current state
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n)   current_state <= STATE_IDLE;
    else          current_state <= next_state;
end

// next state
always @(*) begin
   if (!rst_n)                   next_state = STATE_IDLE;
   else begin
      case (current_state)
         STATE_IDLE: begin
            if (in_valid)        next_state = STATE_INPUT;
            else                 next_state = current_state;
         end
         STATE_INPUT: begin
            if (subcnt==19)      next_state = STATE_OUT;
            else                 next_state = current_state;
         end
         STATE_OUT: begin
            if (cnt==n_input+1)  next_state = STATE_IDLE;
            else                 next_state = current_state;
         end
         default:                next_state = current_state;
      endcase
   end
end

// output logic
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        out_valid <= 0;
        out_mag   <= 0;
        out_phase <= 0;
    end
    else if ((current_state==STATE_OUT) && (cnt>1)) begin
        out_valid <= 1;
        out_mag   <= mag_mem_q;
        out_phase <= phase_mem_q;
    end
    else begin
        out_valid <= 0;
        out_mag   <= 0;
        out_phase <= 0;
    end
end

// counter information
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) cnt <= 0;
   else begin
      case (current_state)
         STATE_IDLE:                cnt <= 0;
         STATE_INPUT: begin
            if (subcnt==19)         cnt <= 0;
            else                    cnt <= cnt + 1;
         end
         STATE_OUT: begin
            if (cnt==n_input+1)     cnt <= 0;
            else                    cnt <= cnt + 1;
         end 
         default:                   cnt <= cnt;
      endcase
   end
end

// sub counter information
always @(posedge clk or negedge rst_n) begin
   if (!rst_n)                                              subcnt <= 0;
   else if ((current_state==STATE_INPUT) && (!in_valid))    subcnt <= subcnt + 1;
   else                                                     subcnt <= 0;
end

// total number of input
always @(posedge clk or negedge rst_n) begin
   if (!rst_n)                                                          n_input <= 0;
   else if ((current_state==STATE_INPUT) && (!in_valid) && (subcnt==0)) n_input <= cnt + 1;
   else if (current_state==STATE_IDLE)                                  n_input <= 0;
   else                                                                 n_input <= n_input;
end

//12bits * 1024 SRAM
RA1SH_12 MEM_12_x(
   .Q(mag_mem_q),
   .CLK(clk),
   .CEN(1'b0),
   .WEN(mag_mem_wen),
   .A(mag_mem_addr),
   .D(mag_mem_data),
   .OEN(1'b0)
);

// mag_mem_wen
always @(posedge clk or negedge rst_n) begin
   if (!rst_n)                            mag_mem_wen <= 1;
   else if (current_state==STATE_INPUT)   mag_mem_wen <= 0;
   else                                   mag_mem_wen <= 1;
end

// mag_mem_addr
always @(posedge clk or negedge rst_n) begin
   if (!rst_n)                            mag_mem_addr <= 0;
   else if (current_state==STATE_INPUT)   mag_mem_addr <= cnt-19;
   else                                   mag_mem_addr <= cnt;
end

// mag_mem_data
always @(posedge clk or negedge rst_n) begin
   if (!rst_n)                            mag_mem_data <= 0;
   else if (current_state==STATE_INPUT)   mag_mem_data <= mag_val_precise[25:14];
   else                                   mag_mem_data <= 0;
end

//21bits * 1024 SRAM
RA1SH_21 MEM_21(
   .Q(phase_mem_q),
   .CLK(clk),
   .CEN(1'b0),
   .WEN(phase_mem_wen),
   .A(phase_mem_addr),
   .D(phase_mem_data),
   .OEN(1'b0)
);

// phase_mem_wen
always @(posedge clk or negedge rst_n) begin
   if (!rst_n)                            phase_mem_wen <= 1;
   else if (current_state==STATE_INPUT)   phase_mem_wen <= 0;
   else                                   phase_mem_wen <= 1;
end

// phase_mem_addr
always @(posedge clk or negedge rst_n) begin
   if (!rst_n)                            phase_mem_addr <= 0;
   else if (current_state==STATE_INPUT)   phase_mem_addr <= cnt-19;
   else                                   phase_mem_addr <= cnt;
end

// phase_mem_data
always @(posedge clk or negedge rst_n) begin
   if (!rst_n)                            phase_mem_data <= 0;
   else if (current_state==STATE_INPUT)   phase_mem_data <= pha_val;
   else                                   phase_mem_data <= 0;
end

// phase and magnitude calculation
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      x_val[0] <= 0;
      y_val[0] <= 0;
      z_val[0] <= 0;
   end
   else begin
      case ({in_x[11],in_y[11]})
         {1'b0,1'b0}: begin
            // I
            x_val[0][23:11] <= in_x;
            y_val[0][23:11] <= in_y;
            z_val[0] <= 0;
         end
         {1'b1,1'b0}: begin
            // II
            x_val[0][23:11] <= in_y;
            y_val[0][23:11] <= -in_x;
            z_val[0] <= {1'b0, 1'b0,1'b1,19'b0}; // 0.5
         end
         {1'b1,1'b1}: begin
            // III
            x_val[0][23:11] <= -in_x;
            y_val[0][23:11] <= -in_y;
            z_val[0] <= {1'b0, 1'b1,20'b0}; // 1
         end
         {1'b0,1'b1}:begin
            // IV
            x_val[0][23:11] <= -in_y;
            y_val[0][23:11] <= in_x;
            z_val[0] <= {1'b0, 1'b1,1'b1,19'b0}; // 1.5
         end
         default: begin // will not happen
            x_val[0][23:11] <= 0;
            y_val[0][23:11] <= 0;
            z_val[0] <= 0;
         end
      endcase
      x_val[0][10:0] <= 0;
      y_val[0][10:0] <= 0;
   end
end

always @(posedge clk) begin
   for (i=0;i<18;i=i+1) begin
      x_val[i+1] <= (y_val[i]<0) ? (x_val[i] - (y_val[i] >>> i)) : (x_val[i] + (y_val[i] >>> i));
      y_val[i+1] <= (y_val[i]<0) ? (y_val[i] + (x_val[i] >>  i)) : (y_val[i] - (x_val[i] >>  i));
      z_val[i+1] <= (y_val[i]<0) ? (z_val[i] - cordic_angle[i])  : (z_val[i] + cordic_angle[i]);
   end
end

// mag_val = x_final_value * Constant
always @(posedge clk) begin
   mag_val_precise <= x_val[18][23:11] * Constant; // 12bit x 15bit
end

always @(posedge clk) begin
   pha_val <= z_val[18][20:0];
end

endmodule