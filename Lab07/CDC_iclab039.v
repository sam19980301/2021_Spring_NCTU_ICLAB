`include "AFIFO.v"

module CDC #(parameter DSIZE = 8,
			   parameter ASIZE = 4)(
	//Input Port
	rst_n,
	clk1,
    clk2,
	in_valid,
	in_account,
	in_A,
	in_T,

    //Output Port
	ready,
    out_valid,
	out_account
); 

//=========INPUT AND OUTPUT DECLARATION==============//

input 				rst_n, clk1, clk2, in_valid;
input [DSIZE-1:0] 	in_account,in_A,in_T;

output reg				out_valid,ready;
output reg [DSIZE-1:0] 	out_account;

//====================PARAMETER=======================//
// Write / Read FSM
parameter W_STATE_DATA = 2'd0; // normal write
parameter W_STATE_WAIT = 2'd1; // buffer wait for full
parameter W_STATE_BACK = 2'd2; // backup write
parameter R_STATE_IDLE = 1'd0;
parameter R_STATE_CALC = 1'd1; // start output data

integer i;
genvar idx;

//==================Wire & Register===================//
// FSM
reg [1:0]   w_current_state, w_next_state;
reg         r_current_state, r_next_state;
reg [2:0]   cnt;

// Asynchronous FIFO signals
wire                winc,  rinc;
wire                wfull, rempty;
reg  [  DSIZE-1:0]  w_acc,  w_inA,  w_inT;
wire [  DSIZE-1:0]  r_acc,  r_inA,  r_inT;

// buffer signals
reg in_valid_buf;
reg rempty_buf[1:0];

// Calculation of best-performance accounts
reg  [  DSIZE-1:0]  account_arr[4:0];
reg  [2*DSIZE-1:0]  performance_arr[4:0];
reg  [  DSIZE-1:0]  better_acc[4:0];
reg  [2*DSIZE-1:0]  better_per[4:0];

wire [2*DSIZE-1:0]  a_mult_t;
wire [  DSIZE-1:0]  answer;


//==================Design===================//
// write FSM
// current state
always @(posedge clk1 or negedge rst_n) begin
    if (!rst_n) w_current_state <= W_STATE_DATA;
    else        w_current_state <= w_next_state;
end

// next state
always @(*) begin
    if (!rst_n)             w_next_state = W_STATE_DATA;
    else begin
        case (w_current_state)
            W_STATE_DATA:   if ((wfull) && (in_valid_buf)) w_next_state = W_STATE_WAIT; else w_next_state = w_current_state;
            W_STATE_WAIT:   if (~wfull) w_next_state = W_STATE_BACK;                    else w_next_state = w_current_state;
            W_STATE_BACK:   w_next_state = W_STATE_DATA;
            default:        w_next_state = w_current_state;
        endcase
    end
end

// current state
always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n) r_current_state <= R_STATE_IDLE;
    else        r_current_state <= r_next_state;
end

// next state
always @(*) begin
    if (!rst_n)                                             r_next_state = R_STATE_IDLE;
    else if ((r_current_state==R_STATE_IDLE) && (cnt==5))   r_next_state = R_STATE_CALC;
    else                                                    r_next_state = r_current_state;
end

// output logic
always @(*) begin
    if (!rst_n) ready = 0;
    else        ready = ((w_current_state==W_STATE_DATA) && (~wfull));
end

always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n)                                                     out_valid <= 0;
    else if ((r_current_state==R_STATE_CALC) && (~rempty_buf[1]))   out_valid <= 1;
    else                                                            out_valid <= 0;
end

always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n)                                                     out_account <= 0;
    else if ((r_current_state==R_STATE_CALC) && (~rempty_buf[1]))   out_account <= answer;
    else                                                            out_account <= 0;
end

// counter information
always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n)         cnt <= 0;
    else if (~rempty)   cnt <= cnt + 1;
    else                cnt <= cnt;
end

// Asynchronous FIFO module // u_AFIFO
AFIFO AFIFO_ACCOUNT( 
    .rclk(clk2),
    .rinc(rinc),
    .rempty(rempty),
	.wclk(clk1),
    .winc(winc),
    .wfull(wfull),
    .rst_n(rst_n),
    .rdata(r_acc),
    .wdata(w_acc)
);

AFIFO AFIFO_INA( 
    .rclk(clk2),
    .rinc(rinc),
    .rempty(rempty),
	.wclk(clk1),
    .winc(winc),
    .wfull(wfull),
    .rst_n(rst_n),
    .rdata(r_inA),
    .wdata(w_inA)
);

AFIFO AFIFO_INT( 
    .rclk(clk2),
    .rinc(rinc),
    .rempty(rempty),
	.wclk(clk1),
    .winc(winc),
    .wfull(wfull),
    .rst_n(rst_n),
    .rdata(r_inT),
    .wdata(w_inT)
);

// Asynchronous FIFO signals
assign winc = (in_valid_buf) || ((w_current_state==W_STATE_BACK) && (~wfull));  // normal write or backup write
assign rinc = (~rempty);

always @(posedge clk1 or negedge rst_n) begin
    if (!rst_n)                                             w_acc <= 0;
    else if ((w_current_state==W_STATE_DATA) && (in_valid)) w_acc <= in_account;
    else                                                    w_acc <= w_acc;
end

always @(posedge clk1 or negedge rst_n) begin
    if (!rst_n)                                             w_inA <= 0;
    else if ((w_current_state==W_STATE_DATA) && (in_valid)) w_inA <= in_A;
    else                                                    w_inA <= w_inA;
end

always @(posedge clk1 or negedge rst_n) begin
    if (!rst_n)                                             w_inT <= 0;
    else if ((w_current_state==W_STATE_DATA) && (in_valid)) w_inT <= in_T;
    else                                                    w_inT <= w_inT;
end

// last 5 account & performance
always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n)         for (i=0;i<5;i=i+1) account_arr[i] <= 0;
    else if (~rempty) begin
                        account_arr[0] <= r_acc;
                        for (i=1;i<5;i=i+1) account_arr[i] <= account_arr[i-1];
    end
    else                for (i=0;i<5;i=i+1) account_arr[i] <= account_arr[i];
end

always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n)         for (i=0;i<5;i=i+1) performance_arr[i] <= 0;
    else if (~rempty) begin
                        performance_arr[0] <= a_mult_t;
                        for (i=1;i<5;i=i+1) performance_arr[i] <= performance_arr[i-1];
    end
    else                for (i=0;i<5;i=i+1) performance_arr[i] <= performance_arr[i];
end

assign a_mult_t = r_inA * r_inT;

// buffer signals
always @(posedge clk1 or negedge rst_n) begin
    if (!rst_n) in_valid_buf <= 0;
    else        in_valid_buf <= in_valid;
end

always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n) rempty_buf[0] <= 1;
    else        rempty_buf[0] <= rempty;
end

always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n) rempty_buf[1] <= 1;
    else        rempty_buf[1] <= rempty_buf[0];
end

// Calculation of best-perforamcne accounts
// performance_arr  [0] [1] [2] [3] [4]
// better_arr           [0] [1] [2] [3] [4]

always @(posedge clk2 or negedge rst_n) begin
    if (!rst_n) begin
        better_per[0] <= 0;
        better_acc[0] <= 0;
    end
    else if (~rempty_buf[0]) begin
        better_per[0] <= performance_arr[0];
        better_acc[0] <= account_arr[0];
    end
    else begin
        better_per[0] <= better_per[0];
        better_acc[0] <= better_acc[0];
    end
end

generate
    for (idx=1;idx<5;idx=idx+1) begin
        always @(posedge clk2 or negedge rst_n) begin
            if (!rst_n) begin
                better_per[idx] <= 0;
                better_acc[idx] <= 0;
            end
            else if (~rempty_buf[0]) begin
                if (performance_arr[0] <= better_per[idx-1]) begin
                    better_per[idx] <= performance_arr[0];
                    better_acc[idx] <= account_arr[0];
                end
                else begin
                    better_per[idx] <= better_per[idx-1];
                    better_acc[idx] <= better_acc[idx-1];
                end
            end
            else begin
                better_per[idx] <= better_per[idx];
                better_acc[idx] <= better_acc[idx];
            end           
        end
    end
endgenerate

assign answer = better_acc[4];

endmodule