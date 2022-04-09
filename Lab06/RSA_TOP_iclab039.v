//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : RSA_TOP.v
//   Module Name : RSA_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "RSA_IP.v"
//synopsys translate_on

module RSA_TOP (
    // Input signals
    clk, rst_n, in_valid,
    in_p, in_q, in_e, in_c,
    // Output signals
    out_valid, out_m
);

//=========INPUT AND OUTPUT DECLARATION==============//
input clk, rst_n, in_valid;
input [3:0] in_p, in_q;
input [7:0] in_e, in_c;
output reg out_valid;
output reg [7:0] out_m;

//==================PARAMETER=====================//
parameter STATE_IDLE =  2'd0;
parameter STATE_INPUT = 2'd1;
parameter STATE_WAIT =  2'd2;
parameter STATE_OUT =   2'd3;

parameter CALC_IDLE = 2'd0;
parameter CALC_PVTK = 2'd1;
parameter CALC_INIT = 2'd2;
parameter CALC_MAIN = 2'd3;

parameter WIDTH = 4;

integer i;

//==================Wire & Register===================//
reg  [1:0] current_state,    next_state;
reg  [2:0] cnt;
reg  [1:0] current_substate, next_substate;
reg  [2:0] subcnt;

reg  [3:0] p_val, q_val;
reg  [7:0] e_val;
reg  [7:0] cipher_arr  [7:0];

wire [7:0] pvt_key_d, pvt_key_n;
reg  [7:0] d_val, n_val;

reg  [7:0] base;
reg  [7:0] exponent;
wire [7:0] modulus;
reg  [7:0] result;
reg  [7:0] decipher_arr[7:0];

wire [15:0] b_mult_b;
wire [15:0] r_mult_b;
wire [7:0] next_base;
wire [7:0] next_result;

wire flag_last, flag_finish;


//========================Design========================//

// Main FSM
// current state
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) current_state <= STATE_IDLE;
    else current_state <= next_state;
end

// next state
always @(*) begin
    if (!rst_n)                                     next_state = STATE_IDLE;
    else begin
        case (current_state)
            STATE_IDLE: begin
                if (in_valid)                       next_state = STATE_INPUT;
                else                                next_state = current_state;
            end
            STATE_INPUT: begin
                if (!in_valid)                      next_state = STATE_WAIT;
                else                                next_state = current_state;
            end
            STATE_WAIT: begin
                if ((flag_last) && (flag_finish))   next_state = STATE_OUT;
                else                                next_state = current_state;
            end
            STATE_OUT: begin
                if (cnt==7)                         next_state = STATE_IDLE;
                else                                next_state = current_state;
            end
            default:                                next_state = current_state;
        endcase
    end
end

// output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 0;
        out_m <= 0;
    end
    else if (current_state == STATE_OUT) begin
        out_valid <= 1;
        out_m <= decipher_arr[cnt];
    end
    else begin
        out_valid <= 0;
        out_m <= 0;
    end
end

// counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                         cnt <= 0;
    else if ((in_valid) || current_state == STATE_OUT)  cnt <= cnt + 1;
    else                                                cnt <= 0;
end

// Sub FSM for calculation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_substate <= CALC_IDLE;
    else        current_substate <= next_substate;
end

// next substate
always @(*) begin
    if (!rst_n)                     next_substate = CALC_IDLE;
    else begin
        case (current_substate)
            CALC_IDLE: begin
                if (in_valid)       next_substate = CALC_PVTK;
                else                next_substate = current_substate;
            end
            CALC_PVTK:              next_substate = CALC_INIT;          
            CALC_INIT: begin
                if (flag_last)      next_substate = CALC_IDLE;
                else                next_substate = CALC_MAIN; 
            end
            CALC_MAIN: begin
                if (flag_finish)    next_substate = CALC_INIT;
                else                next_substate = current_substate;
            end
            default:                next_substate = current_substate;
        endcase
    end
end

// sub counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                                             subcnt <= 0;
    else if ((current_substate==CALC_INIT) || (current_state==STATE_OUT))   subcnt <= subcnt + 1;
    else                                                                    subcnt <= subcnt;
end

assign flag_last = ((subcnt == 0) && (current_state != STATE_INPUT));

// read input
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)             for (i=0;i<8;i=i+1) cipher_arr[i] <= 0;
    else begin
        case (current_state)
            STATE_IDLE:     cipher_arr[0] <= (in_valid) ? in_c : 0;
            STATE_INPUT:    cipher_arr[cnt] <= in_c;
            default:        for (i=0;i<8;i=i+1) cipher_arr[i] <= cipher_arr[i];
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        p_val <= 0;
        q_val <= 0;
        e_val <= 0;
    end
    else if ((current_state==STATE_IDLE) && (in_valid)) begin
        p_val <= in_p;
        q_val <= in_q;
        e_val <= in_e;
    end
    else begin
        p_val <= p_val;
        q_val <= q_val;
        e_val <= e_val;
    end
end

// key generation

RSA_IP #(.WIDTH(WIDTH)) I_RSA_IP (
    .IN_P(p_val),
    .IN_Q(q_val),
    .IN_E(e_val),
    .OUT_N(pvt_key_n),
    .OUT_D(pvt_key_d)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        d_val <= 0;
        n_val <= 0;
    end
    else if (current_substate == CALC_PVTK) begin
        d_val <= pvt_key_d;
        n_val <= pvt_key_n;
    end
    else begin
        d_val <= d_val;
        n_val <= n_val;
    end
end

// decrypting
// c**d (mod N)

// function modular_pow(base, exponent, modulus)
//     result := 1
//     base := base mod modulus
//     while exponent > 0
//         if (exponent mod 2 == 1):
//            result := (result * base) mod modulus
//         exponent := exponent >> 1
//         base := (base * base) mod modulus
//     return result

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)         base <= 0;
    else begin
        case (current_substate)
            // CALC_INIT:  base <= cipher_arr[subcnt] % modulus;
            CALC_INIT:  base <= next_base;
            CALC_MAIN:  base <= next_base;
            default:    base <= 0;
        endcase
    end
end

assign b_mult_b = base*base;
assign next_base = ((current_substate==CALC_INIT) ? cipher_arr[subcnt] : b_mult_b) % modulus;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)         exponent <= 0;
    else begin
        case (current_substate)
            CALC_INIT:  exponent <= d_val;
            CALC_MAIN:  exponent <= exponent >> 1; 
            default:    exponent <= 0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                     result <= 0;
    else begin
        case (current_substate)
            CALC_INIT:              result <= 1;
            CALC_MAIN: begin
                if (exponent[0])    result <= next_result;
                else                result <= result;
            end 
            default:                result <= 0;
        endcase
    end
end

assign r_mult_b = result*base;
assign next_result = r_mult_b % modulus;

assign modulus = n_val;

assign flag_finish = (exponent == 0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) for (i=0;i<8;i=i+1) decipher_arr[i] <= 0;
    else if (flag_finish) begin
        case (subcnt)
            0: decipher_arr[7] <= result;
            1: decipher_arr[0] <= result;
            2: decipher_arr[1] <= result;
            3: decipher_arr[2] <= result;
            4: decipher_arr[3] <= result;
            5: decipher_arr[4] <= result;
            6: decipher_arr[5] <= result;
            default: decipher_arr[6] <= result;
        endcase
    end
    else for (i=0;i<8;i=i+1) decipher_arr[i] <= decipher_arr[i];
end

endmodule