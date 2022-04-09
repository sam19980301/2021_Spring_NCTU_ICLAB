//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : RSA_IP.v
//   Module Name : RSA_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module RSA_IP #(parameter WIDTH = 3) (
    // Input signals
    IN_P, IN_Q, IN_E,
    // Output signals
    OUT_N, OUT_D
);

//=========INPUT AND OUTPUT DECLARATION==============//
input  [WIDTH-1:0]   IN_P, IN_Q;
input  [WIDTH*2-1:0] IN_E;
output [WIDTH*2-1:0] OUT_N, OUT_D;

//==================PARAMETER=====================//
parameter div_count =   (WIDTH==3) ? 5 :
                        (WIDTH==4) ? 8 : 0;
genvar i;
//==================Wire & Register===================//
wire [WIDTH*2-1:0] etf; // euler totient function
//==================Soft IP Design===================//

assign etf = (IN_P-1) * (IN_Q-1);

generate
    for (i=0; i<2+div_count; i=i+1) begin: euclid

        wire [2*WIDTH-1:0] remainder;
        wire [2*WIDTH-1:0] t;
        wire [2*WIDTH-1:0] quotient;

        wire finish;
        wire [2*WIDTH-1:0] result;
        
        if (i==0)       assign remainder = etf;
        else if (i==1)  assign remainder = IN_E;
        else begin
            DW_div_inst #(.width(2*WIDTH)) DIV_CELL(
                .a(euclid[i-2].remainder),
                .b(euclid[i-1].remainder),
                .quotient(quotient),
                .remainder(remainder)
            );
        end

        if (i==0)       assign t = 0;
        else if (i==1)  assign t = 1;
        else            assign t = euclid[i-2].t - quotient * euclid[i-1].t;

        if (i<2)        assign finish = 0;
        else            assign finish = ((euclid[i-1].finish) || (euclid[i-1].remainder==0)) ? 1 : 0;

        if (i<2)                    assign result = 0;
        else if (i==2+div_count-1)  assign result = euclid[i-1].result;
        else                        assign result = (finish) ? euclid[i-1].result : (remainder==0) ? euclid[i-1].t : 0;
    end
endgenerate


assign OUT_N = IN_P * IN_Q;
assign OUT_D = euclid[2+div_count-1].result + (euclid[2+div_count-1].result[2*WIDTH-1] ? etf : 0);
endmodule

module DW_div_inst #(parameter width = 6) (
    // Input signals
    a, b,
    // Output signals
    quotient, remainder
);

// parameter tc_mode = 0;  // unsigned integer
// parameter rem_mode = 1; // corresponds to "%" in Verilog

input   [width-1 : 0] a;
input   [width-1 : 0] b;
output  [width-1 : 0] quotient;
output  [width-1 : 0] remainder;

// DW_div #(width, width, tc_mode, rem_mode) U1(
//     .a(a),
//     .b(b),
//     .quotient(quotient),
//     .remainder(remainder),
//     .divide_by_0()
// );

assign quotient = a / b;
assign remainder = a % b;

endmodule
