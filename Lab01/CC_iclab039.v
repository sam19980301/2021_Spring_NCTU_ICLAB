module CC(
	in_n0,
	in_n1, 
	in_n2, 
	in_n3,
	in_n4, 
	in_n5, 
	opt,
	equ,
	out_n
);

input [3:0] in_n0, in_n1 ,in_n2, in_n3, in_n4, in_n5;
input [2:0] opt;
input equ;
output [9:0] out_n;

//==================================================================
// reg & wire
//==================================================================

reg signed [4:0] signed_n[5:0];
reg cmp[14:0];
reg [2:0] rank[5:0];
wire signed [4:0] sort_n[5:0];
reg signed [4:0] norm_n[5:0];
wire signed [9:0] equation_0, euqation_1_sign, equation_1;
wire signed [9:0] out_n;

//==================================================================
// design
//==================================================================

// Range Discussion
// Case1 unsigned input:bit length 4																	logic range [0,15]
// After sign-extension:bit length 5/5		physical range [-16,15]		intermediate range [0,15]		logic range [0,15]
// After sorting:		bit length 5/5		physical range [-16,15]		intermediate range [0,15]		logic range [0,15]
// After moving avg:	bit length 7/5		physical range [-64,63]		intermediate range [-15,15]		logic range [0,15]
// After shitfting int:	bit length 5/5		physical range [-16,15]		intermediate range [-15,15]		logic range [-15,15]
// After equation 0:	bit length 12/10	physical range [-2048,2047]	intermediate range [-1125,1125]	logic range [-375,375]
// After equation 1:	bit length 10/9		physical range [-512,512]	intermediate range [-450,450]	logic range [-150,150]
// Output:				bit length 10		physical range [-512,511]

// Case1 signed input:	bit length 4																	logic range [-8,7]
// After sign-extension:bit length 4/4		physical range [-8,7]		intermediate range [-8,7]		logic range [-8,7]
// After sorting:		bit length 4/4		physical range [-8,7]		intermediate range [-8,7]		logic range [-8,7]
// After moving avg:	bit length 6/4		physical range [-32,31]		intermediate range [-24,21]		logic range [-8,7]
// After shitfting int:	bit length 5/5		physical range [-16,15]		intermediate range [-15,15]		logic range [-15,15]
// After equation 0:	bit length 12/10	physical range [-2048,2047]	intermediate range [-1125,1125]	logic range [-375,375]
// After equation 1:	bit length 10/9		physical range [-512,512]	intermediate range [-450,450]	logic range [-150,150]
// Output:				bit length 10		physical range [-512,511]

// Corner case example: unsigned, ascending, moving avg, equation 0
// input:				0, 15, 15, 15, 15, 15
// After sign-extension:0, 15, 15, 15, 15, 15
// After sorting: 		0, 15, 15, 15, 15, 15
// After moving avg:	0, 15, 15, 15, 15, 15
// After equation 0:	375 // ((15+15*4)*15)/3 = 1125/3	

// explicit sign-extension, opt[0] ? signed : unsigned
always @(*) begin
	signed_n[0] = {opt[0] & in_n0[3],in_n0};
	signed_n[1] = {opt[0] & in_n1[3],in_n1};
	signed_n[2] = {opt[0] & in_n2[3],in_n2};
	signed_n[3] = {opt[0] & in_n3[3],in_n3};
	signed_n[4] = {opt[0] & in_n4[3],in_n4};
	signed_n[5] = {opt[0] & in_n5[3],in_n5};
end

// exhaustive sorting by counting
always @(*) begin
	cmp[0] = ( signed_n[0] > signed_n[1] ) ^ opt[1];
	cmp[1] = ( signed_n[0] > signed_n[2] ) ^ opt[1];
	cmp[2] = ( signed_n[0] > signed_n[3] ) ^ opt[1];
	cmp[3] = ( signed_n[0] > signed_n[4] ) ^ opt[1];
	cmp[4] = ( signed_n[0] > signed_n[5] ) ^ opt[1];
	cmp[5] = ( signed_n[1] > signed_n[2] ) ^ opt[1];
	cmp[6] = ( signed_n[1] > signed_n[3] ) ^ opt[1];
	cmp[7] = ( signed_n[1] > signed_n[4] ) ^ opt[1];
	cmp[8] = ( signed_n[1] > signed_n[5] ) ^ opt[1];
	cmp[9] = ( signed_n[2] > signed_n[3] ) ^ opt[1];
	cmp[10] = ( signed_n[2] > signed_n[4] ) ^ opt[1];
	cmp[11] = ( signed_n[2] > signed_n[5] ) ^ opt[1];
	cmp[12] = ( signed_n[3] > signed_n[4] ) ^ opt[1];
	cmp[13] = ( signed_n[3] > signed_n[5] ) ^ opt[1];
	cmp[14] = ( signed_n[4] > signed_n[5] ) ^ opt[1];
end

always @(*) begin
	case ({cmp[0],cmp[1],cmp[2],cmp[3],cmp[4]})
		5'b00000: rank[0] =  0 ;
		5'b00001: rank[0] =  1 ;
		5'b00010: rank[0] =  1 ;
		5'b00011: rank[0] =  2 ;
		5'b00100: rank[0] =  1 ;
		5'b00101: rank[0] =  2 ;
		5'b00110: rank[0] =  2 ;
		5'b00111: rank[0] =  3 ;
		5'b01000: rank[0] =  1 ;
		5'b01001: rank[0] =  2 ;
		5'b01010: rank[0] =  2 ;
		5'b01011: rank[0] =  3 ;
		5'b01100: rank[0] =  2 ;
		5'b01101: rank[0] =  3 ;
		5'b01110: rank[0] =  3 ;
		5'b01111: rank[0] =  4 ;
		5'b10000: rank[0] =  1 ;
		5'b10001: rank[0] =  2 ;
		5'b10010: rank[0] =  2 ;
		5'b10011: rank[0] =  3 ;
		5'b10100: rank[0] =  2 ;
		5'b10101: rank[0] =  3 ;
		5'b10110: rank[0] =  3 ;
		5'b10111: rank[0] =  4 ;
		5'b11000: rank[0] =  2 ;
		5'b11001: rank[0] =  3 ;
		5'b11010: rank[0] =  3 ;
		5'b11011: rank[0] =  4 ;
		5'b11100: rank[0] =  3 ;
		5'b11101: rank[0] =  4 ;
		5'b11110: rank[0] =  4 ;
		5'b11111: rank[0] =  5 ;
	endcase
	case ({~cmp[0],cmp[5],cmp[6],cmp[7],cmp[8]})
		5'b00000: rank[1] =  0 ;
		5'b00001: rank[1] =  1 ;
		5'b00010: rank[1] =  1 ;
		5'b00011: rank[1] =  2 ;
		5'b00100: rank[1] =  1 ;
		5'b00101: rank[1] =  2 ;
		5'b00110: rank[1] =  2 ;
		5'b00111: rank[1] =  3 ;
		5'b01000: rank[1] =  1 ;
		5'b01001: rank[1] =  2 ;
		5'b01010: rank[1] =  2 ;
		5'b01011: rank[1] =  3 ;
		5'b01100: rank[1] =  2 ;
		5'b01101: rank[1] =  3 ;
		5'b01110: rank[1] =  3 ;
		5'b01111: rank[1] =  4 ;
		5'b10000: rank[1] =  1 ;
		5'b10001: rank[1] =  2 ;
		5'b10010: rank[1] =  2 ;
		5'b10011: rank[1] =  3 ;
		5'b10100: rank[1] =  2 ;
		5'b10101: rank[1] =  3 ;
		5'b10110: rank[1] =  3 ;
		5'b10111: rank[1] =  4 ;
		5'b11000: rank[1] =  2 ;
		5'b11001: rank[1] =  3 ;
		5'b11010: rank[1] =  3 ;
		5'b11011: rank[1] =  4 ;
		5'b11100: rank[1] =  3 ;
		5'b11101: rank[1] =  4 ;
		5'b11110: rank[1] =  4 ;
		5'b11111: rank[1] =  5 ;
	endcase
	case ({~cmp[1],~cmp[5],cmp[9],cmp[10],cmp[11]})
		5'b00000: rank[2] =  0 ;
		5'b00001: rank[2] =  1 ;
		5'b00010: rank[2] =  1 ;
		5'b00011: rank[2] =  2 ;
		5'b00100: rank[2] =  1 ;
		5'b00101: rank[2] =  2 ;
		5'b00110: rank[2] =  2 ;
		5'b00111: rank[2] =  3 ;
		5'b01000: rank[2] =  1 ;
		5'b01001: rank[2] =  2 ;
		5'b01010: rank[2] =  2 ;
		5'b01011: rank[2] =  3 ;
		5'b01100: rank[2] =  2 ;
		5'b01101: rank[2] =  3 ;
		5'b01110: rank[2] =  3 ;
		5'b01111: rank[2] =  4 ;
		5'b10000: rank[2] =  1 ;
		5'b10001: rank[2] =  2 ;
		5'b10010: rank[2] =  2 ;
		5'b10011: rank[2] =  3 ;
		5'b10100: rank[2] =  2 ;
		5'b10101: rank[2] =  3 ;
		5'b10110: rank[2] =  3 ;
		5'b10111: rank[2] =  4 ;
		5'b11000: rank[2] =  2 ;
		5'b11001: rank[2] =  3 ;
		5'b11010: rank[2] =  3 ;
		5'b11011: rank[2] =  4 ;
		5'b11100: rank[2] =  3 ;
		5'b11101: rank[2] =  4 ;
		5'b11110: rank[2] =  4 ;
		5'b11111: rank[2] =  5 ;
	endcase
	case ({~cmp[2],~cmp[6],~cmp[9],cmp[12],cmp[13]})
		5'b00000: rank[3] =  0 ;
		5'b00001: rank[3] =  1 ;
		5'b00010: rank[3] =  1 ;
		5'b00011: rank[3] =  2 ;
		5'b00100: rank[3] =  1 ;
		5'b00101: rank[3] =  2 ;
		5'b00110: rank[3] =  2 ;
		5'b00111: rank[3] =  3 ;
		5'b01000: rank[3] =  1 ;
		5'b01001: rank[3] =  2 ;
		5'b01010: rank[3] =  2 ;
		5'b01011: rank[3] =  3 ;
		5'b01100: rank[3] =  2 ;
		5'b01101: rank[3] =  3 ;
		5'b01110: rank[3] =  3 ;
		5'b01111: rank[3] =  4 ;
		5'b10000: rank[3] =  1 ;
		5'b10001: rank[3] =  2 ;
		5'b10010: rank[3] =  2 ;
		5'b10011: rank[3] =  3 ;
		5'b10100: rank[3] =  2 ;
		5'b10101: rank[3] =  3 ;
		5'b10110: rank[3] =  3 ;
		5'b10111: rank[3] =  4 ;
		5'b11000: rank[3] =  2 ;
		5'b11001: rank[3] =  3 ;
		5'b11010: rank[3] =  3 ;
		5'b11011: rank[3] =  4 ;
		5'b11100: rank[3] =  3 ;
		5'b11101: rank[3] =  4 ;
		5'b11110: rank[3] =  4 ;
		5'b11111: rank[3] =  5 ;
	endcase
	case ({~cmp[3],~cmp[7],~cmp[10],~cmp[12],cmp[14]})
		5'b00000: rank[4] =  0 ;
		5'b00001: rank[4] =  1 ;
		5'b00010: rank[4] =  1 ;
		5'b00011: rank[4] =  2 ;
		5'b00100: rank[4] =  1 ;
		5'b00101: rank[4] =  2 ;
		5'b00110: rank[4] =  2 ;
		5'b00111: rank[4] =  3 ;
		5'b01000: rank[4] =  1 ;
		5'b01001: rank[4] =  2 ;
		5'b01010: rank[4] =  2 ;
		5'b01011: rank[4] =  3 ;
		5'b01100: rank[4] =  2 ;
		5'b01101: rank[4] =  3 ;
		5'b01110: rank[4] =  3 ;
		5'b01111: rank[4] =  4 ;
		5'b10000: rank[4] =  1 ;
		5'b10001: rank[4] =  2 ;
		5'b10010: rank[4] =  2 ;
		5'b10011: rank[4] =  3 ;
		5'b10100: rank[4] =  2 ;
		5'b10101: rank[4] =  3 ;
		5'b10110: rank[4] =  3 ;
		5'b10111: rank[4] =  4 ;
		5'b11000: rank[4] =  2 ;
		5'b11001: rank[4] =  3 ;
		5'b11010: rank[4] =  3 ;
		5'b11011: rank[4] =  4 ;
		5'b11100: rank[4] =  3 ;
		5'b11101: rank[4] =  4 ;
		5'b11110: rank[4] =  4 ;
		5'b11111: rank[4] =  5 ;
	endcase
	case ({~cmp[4],~cmp[8],~cmp[11],~cmp[13],~cmp[14]})
		5'b00000: rank[5] =  0 ;
		5'b00001: rank[5] =  1 ;
		5'b00010: rank[5] =  1 ;
		5'b00011: rank[5] =  2 ;
		5'b00100: rank[5] =  1 ;
		5'b00101: rank[5] =  2 ;
		5'b00110: rank[5] =  2 ;
		5'b00111: rank[5] =  3 ;
		5'b01000: rank[5] =  1 ;
		5'b01001: rank[5] =  2 ;
		5'b01010: rank[5] =  2 ;
		5'b01011: rank[5] =  3 ;
		5'b01100: rank[5] =  2 ;
		5'b01101: rank[5] =  3 ;
		5'b01110: rank[5] =  3 ;
		5'b01111: rank[5] =  4 ;
		5'b10000: rank[5] =  1 ;
		5'b10001: rank[5] =  2 ;
		5'b10010: rank[5] =  2 ;
		5'b10011: rank[5] =  3 ;
		5'b10100: rank[5] =  2 ;
		5'b10101: rank[5] =  3 ;
		5'b10110: rank[5] =  3 ;
		5'b10111: rank[5] =  4 ;
		5'b11000: rank[5] =  2 ;
		5'b11001: rank[5] =  3 ;
		5'b11010: rank[5] =  3 ;
		5'b11011: rank[5] =  4 ;
		5'b11100: rank[5] =  3 ;
		5'b11101: rank[5] =  4 ;
		5'b11110: rank[5] =  4 ;
		5'b11111: rank[5] =  5 ;
	endcase
end

assign sort_n[0] = (rank[0]==0) ? signed_n[0] :
	(rank[1]==0) ? signed_n[1] :
	(rank[2]==0) ? signed_n[2] :
	(rank[3]==0) ? signed_n[3] :
	(rank[4]==0) ? signed_n[4] :
	signed_n[5];

assign sort_n[1] = (rank[0]==1) ? signed_n[0] :
	(rank[1]==1) ? signed_n[1] :
	(rank[2]==1) ? signed_n[2] :
	(rank[3]==1) ? signed_n[3] :
	(rank[4]==1) ? signed_n[4] :
	signed_n[5];

assign sort_n[2] = (rank[0]==2) ? signed_n[0] :
	(rank[1]==2) ? signed_n[1] :
	(rank[2]==2) ? signed_n[2] :
	(rank[3]==2) ? signed_n[3] :
	(rank[4]==2) ? signed_n[4] :
	signed_n[5];

assign sort_n[3] = (rank[0]==3) ? signed_n[0] :
	(rank[1]==3) ? signed_n[1] :
	(rank[2]==3) ? signed_n[2] :
	(rank[3]==3) ? signed_n[3] :
	(rank[4]==3) ? signed_n[4] :
	signed_n[5];

assign sort_n[4] = (rank[0]==4) ? signed_n[0] :
	(rank[1]==4) ? signed_n[1] :
	(rank[2]==4) ? signed_n[2] :
	(rank[3]==4) ? signed_n[3] :
	(rank[4]==4) ? signed_n[4] :
	signed_n[5];

assign sort_n[5] = (rank[0]==5) ? signed_n[0] :
	(rank[1]==5) ? signed_n[1] :
	(rank[2]==5) ? signed_n[2] :
	(rank[3]==5) ? signed_n[3] :
	(rank[4]==5) ? signed_n[4] :
	signed_n[5];

// // latch-issue however saves much area by 14000
// always @(*) begin
// 	sort_n[rank[0]] = signed_n[0];
// 	sort_n[rank[1]] = signed_n[1];
// 	sort_n[rank[2]] = signed_n[2];
// 	sort_n[rank[3]] = signed_n[3];
// 	sort_n[rank[4]] = signed_n[4];
// 	sort_n[rank[5]] = signed_n[5];
// end

// Cascade sorting performs poor in terms of area by more than 10000
// always @(*) begin
// 	cmp[0] = (signed_n[0] > signed_n[1]) ~^ opt[1];
// 	layer_1[0] = cmp[0] ? signed_n[0] : signed_n[1];
// 	layer_1[1] = cmp[0] ? signed_n[1] : signed_n[0];
// 	cmp[1] = (layer_1[1] > signed_n[2]) ~^ opt[1];
// 	layer_1[2] = cmp[1] ? layer_1[1] : signed_n[2];
// 	layer_1[3] = cmp[1] ? signed_n[2] : layer_1[1];
// 	cmp[2] = (layer_1[0] > layer_1[2]) ~^ opt[1];
// 	layer_1[4] = cmp[2] ? layer_1[0] : layer_1[2];
// 	layer_1[5] = cmp[2] ? layer_1[2] : layer_1[0];
// 	// layer_1[4] > layer_1[5] > layer_1[3]

// 	cmp[3] = (signed_n[3] > signed_n[4]) ~^ opt[1];
// 	layer_1[6] = cmp[3] ? signed_n[3] : signed_n[4];
// 	layer_1[7] = cmp[3] ? signed_n[4] : signed_n[3];
// 	cmp[4] = (layer_1[7] > signed_n[5]) ~^ opt[1];
// 	layer_1[8] = cmp[4] ? layer_1[7] : signed_n[5];
// 	layer_1[9] = cmp[4] ? signed_n[5] : layer_1[7];
// 	cmp[5] = (layer_1[6] > layer_1[8]) ~^ opt[1];
// 	layer_1[10] = cmp[5] ? layer_1[6] : layer_1[8];
// 	layer_1[11] = cmp[5] ? layer_1[8] : layer_1[6];
// 	// layer_1[10] > layer_1[11] > layer_1[9]

// 	cmp[6] = (layer_1[4] > layer_1[10]) ~^ opt[1];
// 	sort_n[0] = cmp[6] ? layer_1[4] : layer_1[10];
// 	layer_2[0] = cmp[6] ? layer_1[10] : layer_1[4];
// 	cmp[7] = (layer_1[3] > layer_1[9]) ~^ opt[1];
// 	layer_2[1] = cmp[7] ? layer_1[3] : layer_1[9];
// 	sort_n[5] = cmp[7] ? layer_1[9] : layer_1[3];
// 	// layer_2[0] layer_2[1] layer_1[5] layer_1[11] remained to be sorted

// 	cmp[8] = (layer_2[0] > layer_2[1]) ~^ opt[1];
// 	layer_3[0] = cmp[8] ? layer_2[0] : layer_2[1];
// 	layer_3[1] = cmp[8] ? layer_2[1] : layer_2[0];
// 	cmp[9] = (layer_1[5] > layer_1[11]) ~^ opt[1];
// 	layer_3[2] = cmp[9] ? layer_1[5] : layer_1[11];
// 	layer_3[3] = cmp[9] ? layer_1[11] : layer_1[5];
// 	// layer_3[0] > layer_3[1], layer_3[2] > layer_3[3]

// 	cmp[10] = (layer_3[0] > layer_3[2]) ~^ opt[1];
// 	sort_n[1] = cmp[10] ? layer_3[0] : layer_3[2];
// 	layer_4[0] = cmp[10] ? layer_3[2] : layer_3[0];
// 	cmp[11] = (layer_3[1] > layer_3[3]) ~^ opt[1];
// 	layer_4[1] = cmp[11] ? layer_3[1] : layer_3[3];
// 	sort_n[4] = cmp[11] ? layer_3[3] : layer_3[1];
// 	// layer_4[0] layer_4[1] remained to be sorted

// 	cmp[12] = (layer_4[0] > layer_4[1]) ~^ opt[1];
// 	sort_n[2] = cmp[12] ? layer_4[0] : layer_4[1];
// 	sort_n[3] = cmp[12] ? layer_4[1] : layer_4[0];
// end

// opt[2] ? moving average : integer shifting
// non-blocking assignment performs poor in terms of area by 2000
always @(*) begin
	if (opt[2]) begin
		norm_n[0] = sort_n[0];
		norm_n[1] = ((norm_n[0] <<< 1) + sort_n[1]) / 3;
		norm_n[2] = ((norm_n[1] <<< 1) + sort_n[2]) / 3;
		norm_n[3] = ((norm_n[2] <<< 1) + sort_n[3]) / 3;
		norm_n[4] = ((norm_n[3] <<< 1) + sort_n[4]) / 3;
		norm_n[5] = ((norm_n[4] <<< 1) + sort_n[5]) / 3;
	end
	else begin
		norm_n[0] = 0;
		norm_n[1] = sort_n[1] - sort_n[0];
		norm_n[2] = sort_n[2] - sort_n[0];
		norm_n[3] = sort_n[3] - sort_n[0];
		norm_n[4] = sort_n[4] - sort_n[0];
		norm_n[5] = sort_n[5] - sort_n[0];
	end
end
// always @(*) begin
// 	if (opt[2]) begin
// 		norm_n[0] <= sort_n[0];
// 		norm_n[1] <= ((sort_n[0] <<< 1) + sort_n[1]) / 3;
// 		norm_n[2] <= ((((sort_n[0] <<< 1) + sort_n[1]) / 3 <<< 1) + sort_n[2]) / 3;
// 		norm_n[3] <= ((((((sort_n[0] <<< 1) + sort_n[1]) / 3 <<< 1) + sort_n[2]) / 3 <<< 1) + sort_n[3]) / 3;
// 		norm_n[4] <= ((((((((sort_n[0] <<< 1) + sort_n[1]) / 3 <<< 1) + sort_n[2]) / 3 <<< 1) + sort_n[3]) / 3 <<< 1) + sort_n[4]) / 3;
// 		norm_n[5] <= ((((((((((sort_n[0] <<< 1) + sort_n[1]) / 3 <<< 1) + sort_n[2]) / 3 <<< 1) + sort_n[3]) / 3 <<< 1) + sort_n[4]) / 3 <<< 1) + sort_n[5]) / 3;
// 	end
// 	else begin
// 		norm_n[0] <= 0;
// 		norm_n[1] <= sort_n[1] - sort_n[0];
// 		norm_n[2] <= sort_n[2] - sort_n[0];
// 		norm_n[3] <= sort_n[3] - sort_n[0];
// 		norm_n[4] <= sort_n[4] - sort_n[0];
// 		norm_n[5] <= sort_n[5] - sort_n[0];
// 	end
// end

// given equation
// procedural-assignment implementation performs poor in terms of area by 4000
assign equation_0 = ((norm_n[3] + (norm_n[4] <<< 2)) * norm_n[5]) / 3;
assign euqation_1_sign = (norm_n[0] - norm_n[1]) * norm_n[5];
assign equation_1 = euqation_1_sign[9]? -euqation_1_sign : euqation_1_sign;
assign out_n = (equ) ? equation_1 : equation_0;
// always @(*) begin
// 	if (equ) begin
// 		equation_1_signed = (norm_n[0] - norm_n[1]) * norm_n[5];
// 		if (equation_1_signed > 0 ) begin
// 			equation = equation_1_signed;
// 		end
// 		else begin
// 			equation = -equation_1_signed;
// 		end
// 		equation = equation_1;
// 	end
// 	else begin
// 		equation = ((norm_n[3] + (norm_n[4] <<< 2)) * norm_n[5]) / 3;
// 	end
// end
// assign out_n = equation;
endmodule