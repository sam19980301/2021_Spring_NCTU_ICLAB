module TMIP(
// input signals
    clk,
    rst_n,
    in_valid,
	in_valid_2,
    image,
	img_size,
    template, 
    action,
	
// output signals
    out_valid,
    out_x,
    out_y,
    out_img_pos,
    out_value
);

//=========INPUT AND OUTPUT DECLARATION==============//
input        clk, rst_n, in_valid, in_valid_2;
input [15:0] image, template;
input [4:0]  img_size;
input [2:0]  action;

output reg        out_valid;
output reg [3:0]  out_x, out_y; 
output reg [7:0]  out_img_pos;
output reg signed[39:0] out_value;

//==================PARAMETER=====================//
parameter STATE_IDLE =          5'd0;
parameter STATE_INPUT_IMG =     5'd1;
parameter STATE_INPUT_ACT =     5'd2;
parameter STATE_PRE_CALC =      5'd3;
parameter STATE_CONV =          5'd4;
parameter STATE_CONV_16 =       5'd5;
parameter STATE_CONV_8 =        5'd6;
parameter STATE_CONV_4 =        5'd7;
parameter STATE_MAX_POOL_16 =   5'd8;
parameter STATE_MAX_POOL_8 =    5'd9;
parameter STATE_MAX_POOL_4 =    5'd10;
parameter STATE_REORDER_IND =   5'd11;
parameter STATE_ZOOM_IN =       5'd12;
parameter STATE_ZOOM_IN_8 =     5'd13;
parameter STATE_ZOOM_IN_4 =     5'd14;
parameter STATE_SHORTCUT =      5'd15;
parameter STATE_SHORTCUT_8 =    5'd16;
parameter STATE_SHORTCUT_4 =    5'd17;
parameter STATE_POST_CALC =     5'd18;
parameter STATE_OUTPUT =        5'd19;

parameter FUNC_CONV =           3'd0;
parameter FUNC_MAXPOOL =        3'd1;
parameter FUNC_HORI_FLIP =      3'd2;
parameter FUNC_VERT_FLIP =      3'd3;
parameter FUNC_LDIAG_FLIP =     3'd4;
parameter FUNC_RDIAG_FLIP =     3'd5;
parameter FUNC_ZOOMIN =         3'd6;
parameter FUNC_SHORTCUT =       3'd7;

parameter ORD_RACA = 3'd0; // rorder type: row ascending then column ascending
parameter ORD_RACD = 3'd1;
parameter ORD_RDCA = 3'd2;
parameter ORD_RDCD = 3'd3;
parameter ORD_CARA = 3'd4;
parameter ORD_CARD = 3'd5;
parameter ORD_CDRA = 3'd6;
parameter ORD_CDRD = 3'd7;

integer i,j;
genvar k;

//==================Wire & Register===================//
// FSM
reg [4:0] current_state, next_state;
reg [8:0] cnt;
reg [7:0] outer_loop;
reg [3:0] inner_loop;

// output
reg [7:0]           max_position;
reg signed [39:0]   max_outvalue;
wire [7:0]          match_position[2:0][2:0];
reg [7:0]           out_img_pos_abs_arr[8:0];
reg [7:0]           out_img_pos_arr[8:0];
reg [3:0]           out_x_val,  out_y_val;

// SRAM & Register Memory
wire signed [15:0]  img_mem_q;
reg                 img_mem_wen;
reg [7:0]           img_mem_addr;
reg signed [15:0]   img_mem_data;
reg [7:0]           r_addr_sig;
reg [7:0]           w_addr_sig;

wire signed [39:0]  ans_mem_q;
reg                 ans_mem_wen;
reg [7:0]           ans_mem_addr;
reg signed [39:0]   ans_mem_data;

// meta information
reg signed [15:0]   image_buf;
reg signed [15:0]   kernel_arr[2:0][2:0];
reg [4:0]           img_shape;
reg [4:0]           next_img_shape;
reg [2:0]           action_arr[15:0];

// reorder index
reg [2:0]           reorder_type;
wire                cf; // column first signal of current reorder type
reg [3:0]           next_start_ind[1:0];
reg [3:0]           start_ind[1:0];
reg [3:0]           abs_start_ind;
reg [3:0]           step[1:0], step_n[1:0]; // 0 for row, 1 for col

// max pooling operation
reg signed [15:0]   max_value;
// zoom-in operation
reg signed [15:0]   zoom_value[3:0];

// convolution operation
reg signed [39:0]   sum_value;
reg signed [15:0]   weight_arr[2:0][2:0];

//==================Design===================//
// state FSM
// current state
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) current_state <= STATE_IDLE;
    else current_state <= next_state;
end

// next state
always @(*) begin
    if (!rst_n)                             next_state = STATE_IDLE;
    else begin
        case (current_state)
            STATE_IDLE: begin           // idle & read first input
                if (in_valid)               next_state = STATE_INPUT_IMG;
                else                        next_state = current_state;
            end
            STATE_INPUT_IMG : begin     // read image, img_size and template
                if (!in_valid)              next_state = STATE_INPUT_ACT;
                else                        next_state = current_state;
            end
            STATE_INPUT_ACT: begin      // read actions
                if (!in_valid_2)            next_state = STATE_PRE_CALC;
                else                        next_state = current_state;
            end
            STATE_PRE_CALC: begin       // prepare calculation
                case (action_arr[cnt])
                    FUNC_CONV:              next_state = STATE_CONV;
                    FUNC_MAXPOOL:           next_state = STATE_MAX_POOL_4;
                    FUNC_HORI_FLIP,
                    FUNC_VERT_FLIP,
                    FUNC_LDIAG_FLIP,
                    FUNC_RDIAG_FLIP:        next_state = STATE_REORDER_IND;
                    FUNC_ZOOMIN:            next_state = STATE_ZOOM_IN;
                    FUNC_SHORTCUT:          next_state = STATE_SHORTCUT; 
                    default:                next_state = current_state; // will not happen
                endcase
            end
            STATE_CONV: begin           // convolution operation
                if      (img_shape==5'd16)  next_state = STATE_CONV_16;
                else if (img_shape==5'd8)   next_state = STATE_CONV_8;
                else                        next_state = STATE_CONV_4;
            end
            STATE_CONV_16: begin        // convolution operation
                if (outer_loop==192)        next_state = STATE_CONV_8;
                else                        next_state = current_state;
            end
            STATE_CONV_8: begin         // convolution operation
                if (outer_loop==48)         next_state = STATE_CONV_4;
                else                        next_state = current_state;
            end
            STATE_CONV_4: begin         // convolution operation
                if (outer_loop==16)         next_state = STATE_OUTPUT;
                else                        next_state = current_state;
            end
            STATE_MAX_POOL_16: begin    // pooling operation
                if (outer_loop==48)         next_state = STATE_POST_CALC;
                else                        next_state = current_state;
            end
            STATE_MAX_POOL_8: begin     // pooling operation
                if (outer_loop==12) begin
                    if (img_shape==8)       next_state = STATE_POST_CALC;
                    else                    next_state = STATE_MAX_POOL_16;
                end
                else                        next_state = current_state;
            end
            STATE_MAX_POOL_4: begin     // pooling operation
                if (img_shape==4)           next_state = STATE_POST_CALC;
                else if (outer_loop==4)     next_state = STATE_MAX_POOL_8;
                else                        next_state = current_state;
            end
            STATE_REORDER_IND:              next_state = STATE_POST_CALC; // flip operation
            STATE_ZOOM_IN: begin        // zoom-in operation
                if      (img_shape==5'd16)  next_state = STATE_POST_CALC;
                else if (img_shape==5'd8)   next_state = STATE_ZOOM_IN_8;
                else                        next_state = STATE_ZOOM_IN_4;
            end
            STATE_ZOOM_IN_8: begin      // zoom-in operation
                if (outer_loop==48)         next_state = STATE_ZOOM_IN_4;
                else                        next_state = current_state;
            end
            STATE_ZOOM_IN_4: begin      // zoom-in operation
                if (outer_loop==16)         next_state = STATE_POST_CALC;
                else                        next_state = current_state;
            end
            STATE_SHORTCUT: begin       // shortcut operation
                if (img_shape==5'd16)       next_state = STATE_SHORTCUT_8;
                else                        next_state = STATE_SHORTCUT_4;
            end
            STATE_SHORTCUT_8: begin       // shortcut operation
                if (outer_loop==48)         next_state = STATE_SHORTCUT_4;
                else                        next_state = current_state;
            end
            STATE_SHORTCUT_4: begin       // shortcut operation
                if (outer_loop==16)         next_state = STATE_POST_CALC;
                else                        next_state = current_state;
            end
            STATE_POST_CALC:                next_state = STATE_PRE_CALC; // finish single calculation
            STATE_OUTPUT: begin         // output
                if (
                    ((img_shape== 4) && (cnt== 17)) ||
                    ((img_shape== 8) && (cnt== 65)) ||
                    ((img_shape==16) && (cnt==257))
                )                           next_state = STATE_IDLE;
                else                        next_state = current_state;
            end
            default:                        next_state = current_state;
        endcase
    end
end

// output logic
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        out_valid <= 0;
        out_x <= 0;
        out_y <= 0;
        out_img_pos <= 0;
        out_value <= 0;
    end
    else if ((current_state==STATE_OUTPUT) && (cnt>1)) begin
        out_valid <= 1;
        out_x <= out_x_val;
        out_y <= out_y_val;
        out_img_pos <= (cnt<11) ? out_img_pos_arr[cnt-2] : 0;
        out_value <= ans_mem_q;
    end
    else begin
        out_valid <= 0;
        out_x <= 0;
        out_y <= 0;
        out_img_pos <= 0;
        out_value <= 0;
    end
end

// action counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 0;
    else begin
        case (current_state)
            STATE_IDLE:         cnt <= 0;                                       // initialization
            STATE_INPUT_IMG:    if (in_valid)   cnt <= cnt + 1; else cnt <= 0;  // counter of input length
            STATE_INPUT_ACT:    if (in_valid_2) cnt <= cnt + 1; else cnt <= 0;  // counter of action length
            STATE_POST_CALC:    cnt <= cnt + 1;                                 // counter of current action
            STATE_CONV:         cnt <= 0;                                       // reset
            STATE_OUTPUT:       cnt <= cnt + 1;                                 // counter of output length
            default:            cnt <= cnt;
        endcase
    end
end

// outer loop signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                             outer_loop <= 0;
    else begin
        case (current_state)
            STATE_CONV_16: begin
                if (outer_loop==192)        outer_loop <= 0;
                else if (inner_loop==11)    outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_CONV_8: begin
                if (outer_loop==48)         outer_loop <= 0;
                else if (inner_loop==11)    outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_CONV_4: begin
                if (outer_loop==16)         outer_loop <= 0;
                else if (inner_loop==11)    outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_MAX_POOL_16: begin
                if (outer_loop==48)         outer_loop <= 0;
                else if (inner_loop==6)     outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_MAX_POOL_8: begin
                if (outer_loop==12)         outer_loop <= 0;
                else if (inner_loop==6)     outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_MAX_POOL_4: begin
                if (outer_loop==4)          outer_loop <= 0;
                else if (inner_loop==6)     outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_ZOOM_IN_8: begin
                if (outer_loop==48)         outer_loop <= 0;
                else if (inner_loop==7)     outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_ZOOM_IN_4: begin
                if (outer_loop==16)         outer_loop <= 0;
                else if (inner_loop==7)     outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_SHORTCUT_8: begin
                if (outer_loop==48)         outer_loop <= 0;
                else if (inner_loop==2)     outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            STATE_SHORTCUT_4: begin
                if (outer_loop==16)         outer_loop <= 0;
                else if (inner_loop==2)     outer_loop <= outer_loop + 1;
                else                        outer_loop <= outer_loop;
            end
            default:                        outer_loop <= 0;
        endcase
    end
end

// inner loop signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                             inner_loop <= 0;
    else begin
        case (current_state)
            STATE_CONV_16,
            STATE_CONV_8,
            STATE_CONV_4: begin
                if (inner_loop==11)                         inner_loop <= 0;
                else                                        inner_loop <= inner_loop + 1;
            end
            STATE_MAX_POOL_16,
            STATE_MAX_POOL_8,
            STATE_MAX_POOL_4: begin
                if (inner_loop==6)                          inner_loop <= 0;
                else                                        inner_loop <= inner_loop + 1;
            end
            STATE_ZOOM_IN_8: begin
                if ((inner_loop==7) || (outer_loop==48))    inner_loop <= 0;
                else                                        inner_loop <= inner_loop + 1;
            end
            STATE_ZOOM_IN_4: begin
                if ((inner_loop==7) || (outer_loop==16))    inner_loop <= 0;
                else                                        inner_loop <= inner_loop + 1;
            end
            STATE_SHORTCUT_8: begin
                if ((inner_loop==2) || (outer_loop==48))    inner_loop <= 0;
                else                                        inner_loop <= inner_loop + 1;
            end
            STATE_SHORTCUT_4: begin
                if ((inner_loop==2) || (outer_loop==16))    inner_loop <= 0;
                else                                        inner_loop <= inner_loop + 1;
            end
            default:                                        inner_loop <= 0;
        endcase
    end
end

// reorder type, refer to REORDER TABLE
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reorder_type <= ORD_RACA;
    end
    else if (current_state==STATE_IDLE) reorder_type <= ORD_RACA; 
    else if (current_state==STATE_REORDER_IND) begin
        case (action_arr[cnt])
            FUNC_HORI_FLIP: case (reorder_type)
                ORD_RACA: reorder_type <= ORD_RACD;
                ORD_RACD: reorder_type <= ORD_RACA;
                ORD_RDCA: reorder_type <= ORD_RDCD;
                ORD_RDCD: reorder_type <= ORD_RDCA;
                ORD_CARA: reorder_type <= ORD_CDRA;
                ORD_CARD: reorder_type <= ORD_CDRD;
                ORD_CDRA: reorder_type <= ORD_CARA;
                ORD_CDRD: reorder_type <= ORD_CARD; 
                default: reorder_type <= reorder_type;
            endcase
            FUNC_VERT_FLIP: case (reorder_type)
                ORD_RACA: reorder_type <= ORD_RDCA;
                ORD_RACD: reorder_type <= ORD_RDCD;
                ORD_RDCA: reorder_type <= ORD_RACA;
                ORD_RDCD: reorder_type <= ORD_RACD;
                ORD_CARA: reorder_type <= ORD_CARD;
                ORD_CARD: reorder_type <= ORD_CARA;
                ORD_CDRA: reorder_type <= ORD_CDRD;
                ORD_CDRD: reorder_type <= ORD_CDRA; 
                default: reorder_type <= reorder_type;
            endcase 
            FUNC_LDIAG_FLIP: case (reorder_type)
                ORD_RACA: reorder_type <= ORD_CDRD;
                ORD_RACD: reorder_type <= ORD_CDRA;
                ORD_RDCA: reorder_type <= ORD_CARD;
                ORD_RDCD: reorder_type <= ORD_CARA;
                ORD_CARA: reorder_type <= ORD_RDCD;
                ORD_CARD: reorder_type <= ORD_RDCA;
                ORD_CDRA: reorder_type <= ORD_RACD;
                ORD_CDRD: reorder_type <= ORD_RACA; 
                default: reorder_type <= reorder_type;
            endcase 
            FUNC_RDIAG_FLIP: case (reorder_type)
                ORD_RACA: reorder_type <= ORD_CARA;
                ORD_RACD: reorder_type <= ORD_CARD;
                ORD_RDCA: reorder_type <= ORD_CDRA;
                ORD_RDCD: reorder_type <= ORD_CDRD;
                ORD_CARA: reorder_type <= ORD_RACA;
                ORD_CARD: reorder_type <= ORD_RACD;
                ORD_CDRA: reorder_type <= ORD_RDCA;
                ORD_CDRD: reorder_type <= ORD_RDCD; 
                default: reorder_type <= reorder_type;
            endcase 
            default: reorder_type <= reorder_type;
        endcase
    end
end

// columns first
assign cf = reorder_type[2];

// starting index
always @(*) begin
    case ({reorder_type,img_shape})
        {ORD_RACA, 5'd4}, {ORD_CARA, 5'd4}: begin start_ind[0] =  6; start_ind[1] =  6; end
        {ORD_RACA,5'd 8}, {ORD_CARA,5'd 8}: begin start_ind[0] =  4; start_ind[1] =  4; end
        {ORD_RACA,5'd16}, {ORD_CARA,5'd16}: begin start_ind[0] =  0; start_ind[1] =  0; end

        {ORD_RACD,5'd 4}, {ORD_CARD,5'd 4}: begin start_ind[0] =  6; start_ind[1] =  9; end
        {ORD_RACD,5'd 8}, {ORD_CARD,5'd 8}: begin start_ind[0] =  4; start_ind[1] = 11; end
        {ORD_RACD,5'd16}, {ORD_CARD,5'd16}: begin start_ind[0] =  0; start_ind[1] = 15; end

        {ORD_RDCA,5'd 4}, {ORD_CDRA,5'd 4}: begin start_ind[0] =  9; start_ind[1] =  6; end
        {ORD_RDCA,5'd 8}, {ORD_CDRA,5'd 8}: begin start_ind[0] = 11; start_ind[1] =  4; end
        {ORD_RDCA,5'd16}, {ORD_CDRA,5'd16}: begin start_ind[0] = 15; start_ind[1] =  0; end

        {ORD_RDCD,5'd 4}, {ORD_CDRD,5'd 4}: begin start_ind[0] =  9; start_ind[1] =  9; end
        {ORD_RDCD,5'd 8}, {ORD_CDRD,5'd 8}: begin start_ind[0] = 11; start_ind[1] = 11; end
        {ORD_RDCD,5'd16}, {ORD_CDRD,5'd16}: begin start_ind[0] = 15; start_ind[1] = 15; end

        default:                    begin start_ind[0] =  0; start_ind[1] =  1; end
    endcase
end

// next starting index
always @(*) begin
    case ({reorder_type,next_img_shape})
        {ORD_RACA, 5'd4}, {ORD_CARA, 5'd4}: begin next_start_ind[0] =  6; next_start_ind[1] =  6; end
        {ORD_RACA,5'd 8}, {ORD_CARA,5'd 8}: begin next_start_ind[0] =  4; next_start_ind[1] =  4; end
        {ORD_RACA,5'd16}, {ORD_CARA,5'd16}: begin next_start_ind[0] =  0; next_start_ind[1] =  0; end

        {ORD_RACD,5'd 4}, {ORD_CARD,5'd 4}: begin next_start_ind[0] =  6; next_start_ind[1] =  9; end
        {ORD_RACD,5'd 8}, {ORD_CARD,5'd 8}: begin next_start_ind[0] =  4; next_start_ind[1] = 11; end
        {ORD_RACD,5'd16}, {ORD_CARD,5'd16}: begin next_start_ind[0] =  0; next_start_ind[1] = 15; end

        {ORD_RDCA,5'd 4}, {ORD_CDRA,5'd 4}: begin next_start_ind[0] =  9; next_start_ind[1] =  6; end
        {ORD_RDCA,5'd 8}, {ORD_CDRA,5'd 8}: begin next_start_ind[0] = 11; next_start_ind[1] =  4; end
        {ORD_RDCA,5'd16}, {ORD_CDRA,5'd16}: begin next_start_ind[0] = 15; next_start_ind[1] =  0; end

        {ORD_RDCD,5'd 4}, {ORD_CDRD,5'd 4}: begin next_start_ind[0] =  9; next_start_ind[1] =  9; end
        {ORD_RDCD,5'd 8}, {ORD_CDRD,5'd 8}: begin next_start_ind[0] = 11; next_start_ind[1] = 11; end
        {ORD_RDCD,5'd16}, {ORD_CDRD,5'd16}: begin next_start_ind[0] = 15; next_start_ind[1] = 15; end

        default: begin next_start_ind[0] = 0; next_start_ind[1] = 0; end
    endcase
end

// absolute starting index
always @(*) begin
    case (img_shape)
        4:          abs_start_ind = 6;
        8:          abs_start_ind = 4;
        16:         abs_start_ind = 0;
        default:    abs_start_ind = 0;
    endcase  
end

// step
always @(*) begin
    case (reorder_type)
        ORD_RACA, ORD_CARA: begin step[0] =  4'd1; step[1] =  4'd1; end 
        ORD_RACD, ORD_CARD: begin step[0] =  4'd1; step[1] = -4'd1; end 
        ORD_RDCA, ORD_CDRA: begin step[0] = -4'd1; step[1] =  4'd1; end 
        ORD_RDCD, ORD_CDRD: begin step[0] = -4'd1; step[1] = -4'd1; end 
        default:    begin step[0] =     0; step[1] =     0; end
    endcase
end

// step negative
always @(*) begin
    step_n[0] = ~step[0] + 1;
    step_n[1] = ~step[1] + 1;
end

// template / kernel arr
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i=0;i<3;i=i+1) begin
            for (j=0;j<3;j=j+1) begin
                kernel_arr[i][j] <= 0;
            end
        end
    end
    else if (in_valid) begin
        if (current_state==STATE_IDLE)  kernel_arr[0][0] <= template;
        else begin
            case (cnt)
                // 0: kernel_arr[0][0] <= template; 
                0: kernel_arr[0][1] <= template; 
                1: kernel_arr[0][2] <= template; 
                2: kernel_arr[1][0] <= template; 
                3: kernel_arr[1][1] <= template; 
                4: kernel_arr[1][2] <= template; 
                5: kernel_arr[2][0] <= template; 
                6: kernel_arr[2][1] <= template;
                7: kernel_arr[2][2] <= template; 
                default: begin
                    for (i=0;i<3;i=i+1) begin
                        for (j=0;j<3;j=j+1) begin
                            kernel_arr[i][j] <= kernel_arr[i][j];
                        end
                    end
                end
            endcase
        end
    end
    else begin
        for (i=0;i<3;i=i+1) begin
            for (j=0;j<3;j=j+1) begin
                kernel_arr[i][j] <= kernel_arr[i][j];
            end
        end
    end
end

// image buffer
always @(posedge clk) begin
    image_buf <= image;
end

// shape of image
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) img_shape <= 0;
    else if ((current_state==STATE_IDLE) && (in_valid))     img_shape <= img_size;
    else if (current_state==STATE_POST_CALC)                img_shape <= next_img_shape;
    else                                                    img_shape <= img_shape;
end

// next image shape
always @(*) begin
    case (action_arr[cnt])
        FUNC_MAXPOOL: begin
            if (img_shape==4)       next_img_shape =  4;
            else if (img_shape==8)  next_img_shape =  4;
            else                    next_img_shape =  8;
        end
        FUNC_ZOOMIN: begin
            if (img_shape==4)       next_img_shape =  8;
            else if (img_shape==8)  next_img_shape = 16;
            else                    next_img_shape = 16;
        end
        FUNC_SHORTCUT: begin
            if (img_shape==16)      next_img_shape =  8;
            else                    next_img_shape =  4;
        end
        default:                    next_img_shape = img_shape;
    endcase
end

// image memory SRAM
IMG_MEM_100MHz IMG_SRAM(
   .Q(img_mem_q),
   .CLK(clk),
   .CEN(1'b0),
   .WEN(img_mem_wen),
   .A(img_mem_addr),
   .D(img_mem_data),
   .OEN(1'b0)
);

// image SRAM signals
// write-enable-negative
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) img_mem_wen <= 1;
    else begin
        case (current_state)
            STATE_IDLE:         img_mem_wen <= 1;
            STATE_INPUT_IMG:    img_mem_wen <= 0;
            STATE_MAX_POOL_16,
            STATE_MAX_POOL_8,
            STATE_MAX_POOL_4:   if (inner_loop<6)                       img_mem_wen <= 1;   else img_mem_wen <= 0;
            STATE_ZOOM_IN_8,
            STATE_ZOOM_IN_4:    if ((inner_loop <3) || (inner_loop> 6)) img_mem_wen <= 1;   else img_mem_wen <= 0;
            STATE_SHORTCUT_8,
            STATE_SHORTCUT_4:   if ((inner_loop==0) || (inner_loop==2)) img_mem_wen <= 1;   else img_mem_wen <= 0; 
            default: img_mem_wen <= 1; 
        endcase
    end
end

// image address signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) img_mem_addr <= 0;
    else begin
        case (current_state)
            STATE_INPUT_IMG: begin
                case (img_shape)
                     4: begin
                                                    img_mem_addr[7:4] <= start_ind[0] + (cnt[3:2]);
                                                    img_mem_addr[3:0] <= start_ind[1] + (cnt[1:0]);
                    end
                     8: begin
                                                    img_mem_addr[7:4] <= start_ind[0] + (cnt[5:3]);
                                                    img_mem_addr[3:0] <= start_ind[1] + (cnt[2:0]);
                    end 
                    16: begin
                                                    img_mem_addr[7:4] <= start_ind[0] + (cnt[7:4]);
                                                    img_mem_addr[3:0] <= start_ind[1] + (cnt[3:0]);
                    end 
                    default:                        img_mem_addr <= img_mem_addr;
                endcase
            end
            STATE_CONV,                         
            STATE_ZOOM_IN:                          img_mem_addr <= {     start_ind[0],     start_ind[1]};
            STATE_SHORTCUT:                         img_mem_addr <= {next_start_ind[0],next_start_ind[1]}; // AAA
            STATE_CONV_16: begin
                case (inner_loop)
                      0,  6,  7: begin // right
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 :   step[1]);
                    end
                      1,  8    : begin // down
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 :   step[1]);
                    end
                      2,  3,  9: begin // left
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 : step_n[1]);
                    end
                      4,  5    : begin // up
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 : step_n[1]);
                    end
                     11: begin
                        case (outer_loop)
                             0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
                            59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72,
                            111,112,113,114,115,116,117,118,119,120,121,122,
                            155,156,157,158,159,160,161,162,163,164,
                            191: begin // right
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 :   step[1]);
                            end
                            15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
                            73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85,
                            123,124,125,126,127,128,129,130,131,132,133,
                            165,166,167,168,169,170,171,172,173: begin // down
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 :   step[1]);
                            end
                            30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44,
                            86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98,
                            134,135,136,137,138,139,140,141,142,143,144,
                            174,175,176,177,178,179,180,181,182: begin // left
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 : step_n[1]);
                            end
                            45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58,
                            99,100,101,102,103,104,105,106,107,108,109,110,
                            145,146,147,148,149,150,151,152,153,154,
                            183,184,185,186,187,188,189,190: begin // up
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 : step_n[1]);
                            end
                            default:                img_mem_addr <= img_mem_addr;
                        endcase
                     end
                    default:                        img_mem_addr <= img_mem_addr;
                    //   6   7   8
                    //   5   0   1(9)
                    //   4   3   2 
                endcase
            end
            STATE_CONV_8: begin
                case (inner_loop)
                      0,  6,  7: begin // right
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 :   step[1]);
                    end
                      1,  8    : begin // down
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 :   step[1]);
                    end
                      2,  3,  9: begin // left
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 : step_n[1]);
                    end
                      4,  5    : begin // up
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 : step_n[1]);
                    end
                     11: begin
                        case (outer_loop)
                              0,  1,  2,  3,  4,  5,  6,
                             27, 28, 29, 30, 31, 32,
                             47: begin // right
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 :   step[1]);
                        end
                              7,  8,  9, 10, 11, 12, 13,
                             33, 34, 35, 36, 37: begin // down
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 :   step[1]);
                        end
                             14, 15, 16, 17, 18, 19, 20,
                             38, 39, 40, 41, 42: begin // left
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 : step_n[1]);
                        end
                             21, 22, 23, 24, 25, 26,
                             43, 44, 45, 46: begin // up
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 : step_n[1]);
                        end
                        default:                    img_mem_addr <= img_mem_addr;
                        endcase
                    end
                    default:                        img_mem_addr <= img_mem_addr;
                endcase
            end
            STATE_CONV_4: begin
                case (inner_loop)
                      0,  6,  7: begin // right
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 :   step[1]);
                    end
                      1,  8    : begin // down
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 :   step[1]);
                    end
                      2,  3,  9: begin // left
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 : step_n[1]);
                    end
                      4,  5    : begin // up
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 : step_n[1]);
                    end
                     11: begin
                        case (outer_loop)
                              0,  1,  2,
                             11, 12: begin // right
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 :   step[1]);
                             end
                              3,  4,  5,
                             13: begin // down
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ?   step[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 :   step[1]);
                             end
                              6,  7,  8,
                             14: begin // left
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 : step_n[1]);
                             end
                              9, 10: begin // up
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ? step_n[0] : 4'd0);
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 : step_n[1]);
                             end
                            default:                img_mem_addr <= img_mem_addr;
                        endcase
                    end
                    default:                        img_mem_addr <= img_mem_addr;
                endcase
            end
            STATE_MAX_POOL_16,
            STATE_MAX_POOL_8,
            STATE_MAX_POOL_4: begin
                if (inner_loop<6)                   img_mem_addr <= r_addr_sig;
                else                                img_mem_addr <= w_addr_sig;
            end
            STATE_ZOOM_IN_8,
            STATE_ZOOM_IN_4: begin
                if (inner_loop<2)                   img_mem_addr <= r_addr_sig;
                else                                img_mem_addr <= w_addr_sig;
            end
            STATE_SHORTCUT_8: begin
                if (inner_loop==2) begin
                    case (outer_loop)
                          0,  1,  2,  3,  4,  5,  6,
                         27, 28, 29, 30, 31, 32,
                         47: begin // right
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ?   step[0] : 4'd0); 
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 :   step[1]); 
                        end
                          7,  8,  9, 10, 11, 12, 13,
                         33, 34, 35, 36, 37: begin // down
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ?   step[0] : 4'd0); 
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 :   step[1]); 
                        end 
                         14, 15, 16, 17, 18, 19, 20,
                         38, 39, 40, 41, 42: begin // left
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 : step_n[1]); 
                        end 
                         21, 22, 23, 24, 25, 26,
                         43, 44, 45, 46: begin // up
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 : step_n[1]);
                        end
                        default:                    img_mem_addr <= img_mem_addr;
                    endcase
                end
                else                                img_mem_addr <= img_mem_addr;
            end
            STATE_SHORTCUT_4: begin
                if (inner_loop==2) begin
                    case (outer_loop)
                          0,  1,  2,
                         11, 12: begin // right
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ?   step[0] : 4'd0); 
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 :   step[1]); 
                        end
                          3,  4,  5,
                         13: begin // down
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ?   step[0] : 4'd0); 
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 :   step[1]); 
                        end 
                          6,  7,  8,
                         14: begin // left
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + ( cf ? 4'd0 : step_n[1]); 
                        end 
                          9, 10,
                         15: begin // up
                                                    img_mem_addr[7:4] <= img_mem_addr[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                    img_mem_addr[3:0] <= img_mem_addr[3:0] + (!cf ? 4'd0 : step_n[1]);
                        end
                        default:                    img_mem_addr <= img_mem_addr;
                    endcase
                end
                else                                img_mem_addr <= img_mem_addr;
            end
            default:                                img_mem_addr <= 0;
        endcase
    end
end

// read address signal, specified for img_mem_addr one cycle ahead
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                 r_addr_sig <= 0;
    else begin
        case (current_state)
            STATE_PRE_CALC: begin
                                                r_addr_sig[7:4] <= start_ind[0] + ((img_shape==8) ? 2 : 6) * step[0]; // shift index for pooling
                                                r_addr_sig[3:0] <= start_ind[1] + ((img_shape==8) ? 2 : 6) * step[1]; // shift index for pooling
            end
            STATE_MAX_POOL_16: begin
                case (inner_loop)
                    0: begin // right
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                    end 
                    1: begin // down
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                    end 
                    2: begin // left
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                    end 
                    3: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                    end
                    6:                          r_addr_sig <= r_addr_sig;
                    default: begin
                        case (outer_loop)
                              0,  1,  2,  3,  4,  5,  6,
                             27, 28, 29, 30, 31, 32,
                             47: begin // right
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                            end
                              7,  8,  9, 10, 11, 12, 13,
                             33, 34, 35, 36, 37: begin // down
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                            end
                             14, 15, 16, 17, 18, 19, 20,
                             38, 39, 40, 41, 42: begin // left
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                            end
                             21, 22, 23, 24, 25, 26,
                             43, 44, 45, 46: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                            end
                            default:            r_addr_sig <= r_addr_sig;
                        endcase
                    end
                endcase
            end
            STATE_MAX_POOL_8: begin
                case (inner_loop)
                    0: begin // right
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                    end 
                    1: begin // down
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                    end 
                    2: begin // left
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                    end 
                    3: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                    end
                    6:                          r_addr_sig <= r_addr_sig;
                    default: begin
                        case (outer_loop)
                              0,  1,  2: begin // right
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                            end
                              3,  4,  5: begin // down
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                            end
                              6,  7,  8: begin // left
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                            end
                              9, 10: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                            end
                             11: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0) + (4/2) * step_n[0];
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]) + (4/2) * step_n[1];
                            end
                            default:            r_addr_sig <= r_addr_sig;
                        endcase
                    end
                endcase
            end
            STATE_MAX_POOL_4: begin
                case (inner_loop)
                    0: begin // right
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                    end 
                    1: begin // down
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                    end 
                    2: begin // left
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                    end 
                    3: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                    end
                    6:                          r_addr_sig <= r_addr_sig;
                    default: begin
                        case (outer_loop)
                            0: begin // right
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                            end 
                            1: begin // down
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                            end 
                            2: begin // left
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                            end 
                            3: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0) + (2/2) * step_n[0];
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]) + (2/2) * step_n[1];
                            end
                            default:            r_addr_sig <= r_addr_sig;
                        endcase
                    end
                endcase
            end
            STATE_ZOOM_IN:                      r_addr_sig <= {     start_ind[0],     start_ind[1]};
            STATE_ZOOM_IN_8: begin
                if (inner_loop==6) begin
                    case (outer_loop)
                         0,  1,  2,  3,  4,  5,  6,
                        27, 28, 29, 30, 31, 32,
                        47: begin // right
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                        end
                         7,  8,  9, 10, 11, 12, 13,
                        33, 34, 35, 36, 37: begin // down
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                        end 
                        14, 15, 16, 17, 18, 19, 20,
                        38, 39, 40, 41, 42: begin // left
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                        end 
                        21, 22, 23, 24, 25, 26,
                        43, 44, 45, 46: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                        end
                        default:                r_addr_sig <= r_addr_sig;
                    endcase
                end
                else                            r_addr_sig <= r_addr_sig;
            end
            STATE_ZOOM_IN_4: begin
                if (inner_loop==6) begin
                    case (outer_loop)
                          0,  1,  2,
                         11, 12: begin // right
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                        end
                          3,  4,  5,
                         13: begin // down
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                        end 
                          6,  7,  8,
                         14: begin // left
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                        end 
                          9, 10,
                         15: begin // up
                                                r_addr_sig[7:4] <= r_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                                r_addr_sig[3:0] <= r_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                        end
                        default:                r_addr_sig <= r_addr_sig;
                    endcase
                end
                else                            r_addr_sig <= r_addr_sig;
            end
            default:                            r_addr_sig <= r_addr_sig;
        endcase
    end
end

// write address signal, specified for img_mem_addr one cycle ahead
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                         w_addr_sig <= 0;
    else begin
        case (current_state)
            STATE_PRE_CALC:begin
                                        w_addr_sig[7:4] <= start_ind[0] + ((img_shape==8) ? 3 : 7) * step[0]; // shift index for pooling
                                        w_addr_sig[3:0] <= start_ind[1] + ((img_shape==8) ? 3 : 7) * step[1]; // shift index for pooling
            end                         
            STATE_MAX_POOL_16: begin
                if (inner_loop==6) begin
                    case (outer_loop)
                        0,  1,  2,  3,  4,  5,  6,
                        27, 28, 29, 30, 31, 32,
                        47: begin // right
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                        end
                        7,  8,  9, 10, 11, 12, 13,
                        33, 34, 35, 36, 37: begin // down
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                        end 
                        14, 15, 16, 17, 18, 19, 20,
                        38, 39, 40, 41, 42: begin // left
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                        end 
                        21, 22, 23, 24, 25, 26,
                        43, 44, 45, 46: begin // up
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                        end
                        default:        w_addr_sig <= w_addr_sig;
                    endcase
                end
                else                    w_addr_sig <= w_addr_sig;
            end
            STATE_MAX_POOL_8: begin
                if (inner_loop==6) begin
                    case (outer_loop)
                          0,  1,  2: begin // right
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                        end
                          3,  4,  5: begin // down
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                        end 
                          6,  7,  8: begin // left
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                        end 
                          9, 10: begin // up
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                        end
                         11: begin // up
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0) + 2 * step_n[0];
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]) + 2 * step_n[1];
                        end
                        default:        w_addr_sig <= w_addr_sig;
                    endcase
                end
                else                    w_addr_sig <= w_addr_sig;
            end
            STATE_MAX_POOL_4: begin
                if (inner_loop==6) begin
                    case (outer_loop)
                          0: begin // right
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                        end
                          1: begin // down
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                        end 
                          2: begin // left
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                        end 
                          3: begin // up
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0) + 1 * step_n[0]; 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]) + 1 * step_n[1];
                        end
                        default:        w_addr_sig <= w_addr_sig;
                    endcase
                end
                else                    w_addr_sig <= w_addr_sig;
            end
            STATE_ZOOM_IN:              w_addr_sig <= {next_start_ind[0],next_start_ind[1]};
            STATE_ZOOM_IN_8: begin
                case (inner_loop)
                    3: begin // right
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                    end 
                    4: begin // down
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                    end 
                    5: begin // left
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                    end 
                    6: begin // up
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                    end
                    0, 1, 2:               w_addr_sig <= w_addr_sig;
                    default: begin
                        case (outer_loop)
                              0,  1,  2,  3,  4,  5,  6,
                             27, 28, 29, 30, 31, 32,
                             47: begin // right
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + 2 * ( cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + 2 * ( cf ? 4'd0 :   step[1]); 
                            end
                              7,  8,  9, 10, 11, 12, 13,
                             33, 34, 35, 36, 37: begin // down
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + 2 * (!cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + 2 * (!cf ? 4'd0 :   step[1]); 
                            end
                             14, 15, 16, 17, 18, 19, 20,
                             38, 39, 40, 41, 42: begin // left
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + 2 * ( cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + 2 * ( cf ? 4'd0 : step_n[1]); 
                            end
                             21, 22, 23, 24, 25, 26,
                             43, 44, 45, 46: begin // up
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + 2 * (!cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + 2 * (!cf ? 4'd0 : step_n[1]);
                            end
                            default:    w_addr_sig <= w_addr_sig;
                        endcase
                    end
                endcase
            end
            STATE_ZOOM_IN_4: begin
                case (inner_loop)
                    3: begin // right
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 :   step[1]); 
                    end 
                    4: begin // down
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 :   step[1]); 
                    end 
                    5: begin // left
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + ( cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + ( cf ? 4'd0 : step_n[1]); 
                    end 
                    6: begin // up
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + (!cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + (!cf ? 4'd0 : step_n[1]);
                    end
                    0, 1, 2:               w_addr_sig <= w_addr_sig;
                    default: begin
                        case (outer_loop)
                              0,  1,  2,
                             11, 12: begin // right
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + 2 * ( cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + 2 * ( cf ? 4'd0 :   step[1]); 
                            end
                              3,  4,  5,
                             13: begin // down
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + 2 * (!cf ?   step[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + 2 * (!cf ? 4'd0 :   step[1]); 
                            end
                              6,  7,  8,
                             14: begin // left
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + 2 * ( cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + 2 * ( cf ? 4'd0 : step_n[1]); 
                            end
                              9, 10,
                             15: begin // up
                                        w_addr_sig[7:4] <= w_addr_sig[7:4] + 2 * (!cf ? step_n[0] : 4'd0); 
                                        w_addr_sig[3:0] <= w_addr_sig[3:0] + 2 * (!cf ? 4'd0 : step_n[1]);
                            end
                            default:    w_addr_sig <= w_addr_sig;
                        endcase
                    end
                endcase
            end
            default:                    w_addr_sig <= w_addr_sig;
        endcase
    end  
end

// image data signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                     img_mem_data <= 0;
    else begin
        case (current_state)
            STATE_IDLE:             img_mem_data <= 0;
            STATE_INPUT_IMG:        img_mem_data <= image_buf;
            STATE_MAX_POOL_16,
            STATE_MAX_POOL_8,
            STATE_MAX_POOL_4:       img_mem_data <= max_value;
            STATE_ZOOM_IN_8,
            STATE_ZOOM_IN_4: begin
                case (inner_loop)
                    3:              img_mem_data <= zoom_value[0];
                    4:              img_mem_data <= zoom_value[1];
                    5:              img_mem_data <= zoom_value[2];
                    6:              img_mem_data <= zoom_value[3];
                    default:        img_mem_data <= 0;
                endcase
            end
            STATE_SHORTCUT_8,
            STATE_SHORTCUT_4: begin
                if (inner_loop==1)  img_mem_data <= (img_mem_q / 2) - (((img_mem_q[15]==1) && (img_mem_q[0]==1)) ? 1 : 0) + 50;
                else                img_mem_data <= img_mem_data;
            end
            default:                img_mem_data <= 0;
        endcase
    end
end

// answer memory SRAM
ANS_MEM_100MHz ANS_SRAM(
   .Q(ans_mem_q),
   .CLK(clk),
   .CEN(1'b0),
   .WEN(ans_mem_wen),
   .A(ans_mem_addr),
   .D(ans_mem_data),
   .OEN(1'b0)
);

// answer write enable negative signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                 ans_mem_wen <= 1;
    else if (inner_loop==10)    ans_mem_wen <= 0;
    else                        ans_mem_wen <= 1;
end

// answer memory address
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                         ans_mem_addr <= 0;
    else if (current_state==STATE_IDLE) ans_mem_addr <= 0;
    else if (current_state==STATE_CONV) begin
                                        ans_mem_addr[7:4] <= abs_start_ind;
                                        ans_mem_addr[3:0] <= abs_start_ind;
    end
    else if ((current_state==STATE_OUTPUT)) begin
        if (cnt==0) begin
                                        ans_mem_addr[7:4] <= abs_start_ind;
                                        ans_mem_addr[3:0] <= abs_start_ind; 
        end
        else begin
            case (img_shape)
                  4: begin
                                        ans_mem_addr[7:4] <= abs_start_ind + (cnt/4);
                                        ans_mem_addr[3:0] <= abs_start_ind + (cnt%4);
                end
                  8: begin
                                        ans_mem_addr[7:4] <= abs_start_ind + (cnt/8);
                                        ans_mem_addr[3:0] <= abs_start_ind + (cnt%8);
                end 
                 16: begin
                                        ans_mem_addr[7:4] <= abs_start_ind + (cnt/16);
                                        ans_mem_addr[3:0] <= abs_start_ind + (cnt%16);
                end 
                default:                ans_mem_addr <= ans_mem_addr;
            endcase
        end
    end
    else if (inner_loop==11) begin
        case (current_state)
            STATE_CONV_16: begin
                case (outer_loop)
                      0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
                     59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72,
                    111,112,113,114,115,116,117,118,119,120,121,122,
                    155,156,157,158,159,160,161,162,163,164,
                    191: begin // right
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 0;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 1;
                    end
                     15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
                     73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85,
                    123,124,125,126,127,128,129,130,131,132,133,
                    165,166,167,168,169,170,171,172,173: begin // down
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 1;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 0;
                    end
                     30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44,
                     86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98,
                    134,135,136,137,138,139,140,141,142,143,144,
                    174,175,176,177,178,179,180,181,182: begin // left
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 0;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] - 1;
                    end
                     45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58,
                     99,100,101,102,103,104,105,106,107,108,109,110,
                    145,146,147,148,149,150,151,152,153,154,
                    183,184,185,186,187,188,189,190: begin // up
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] - 1;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 0;
                    end
                    default:            ans_mem_addr <= ans_mem_addr;
                endcase
            end
            STATE_CONV_8: begin
                case (outer_loop)
                      0,  1,  2,  3,  4,  5,  6,
                     27, 28, 29, 30, 31, 32,
                     47: begin // right
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 0;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 1;
                    end
                      7,  8,  9, 10, 11, 12, 13,
                     33, 34, 35, 36, 37: begin // down
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 1;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 0;
                    end
                     14, 15, 16, 17, 18, 19, 20,
                     38, 39, 40, 41, 42: begin // left
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 0;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] - 1;
                    end
                     21, 22, 23, 24, 25, 26,
                     43, 44, 45, 46: begin // up
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] - 1;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 0;
                    end
                    default:            ans_mem_addr <= ans_mem_addr;
                endcase
            end
            STATE_CONV_4: begin
                case (outer_loop)
                      0,  1,  2,
                     11, 12: begin // right
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 0;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 1;
                    end
                      3,  4,  5,
                     13: begin // down
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 1;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 0;
                    end
                      6,  7,  8,
                     14: begin // left
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] + 0;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] - 1;
                    end
                      9, 10: begin // up
                                        ans_mem_addr[7:4] <= ans_mem_addr[7:4] - 1;
                                        ans_mem_addr[3:0] <= ans_mem_addr[3:0] + 0;
                    end
                     15: begin // TBD
                                        ans_mem_addr[7:4] <= abs_start_ind;
                                        ans_mem_addr[3:0] <= abs_start_ind; 
                     end
                default:                ans_mem_addr <= ans_mem_addr;
                endcase
            end
            default:                    ans_mem_addr <= ans_mem_addr;
        endcase
    end
    else                                ans_mem_addr <= ans_mem_addr;
end

// answer memory data
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     ans_mem_data <= 0;
    else            ans_mem_data <= sum_value;
end

// max pooling calculation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)         max_value <= 0;
    else begin
        case (inner_loop)
            2, 3, 4, 5: max_value <= (max_value > img_mem_q) ? max_value : img_mem_q;
            default:    max_value <= {1'b1,15'b0};
        endcase
    end
end

// zoom-in calculation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        zoom_value[0] <= 0;
        zoom_value[1] <= 1;
        zoom_value[2] <= 2;
        zoom_value[3] <= 3;
    end
    else if (inner_loop==2) begin
        zoom_value[0] <= img_mem_q;
        zoom_value[1] <= img_mem_q / 3;
        zoom_value[2] <= (img_mem_q / 2) - (((img_mem_q[15]==1) && (img_mem_q[0]==1)) ? 1 : 0);
        zoom_value[3] <= img_mem_q * 2 / 3 + 20;
    end
    else begin
        zoom_value[0] <= zoom_value[0];
        zoom_value[1] <= zoom_value[1];
        zoom_value[2] <= zoom_value[2];
        zoom_value[3] <= zoom_value[3];
    end
end

// summation of convolution
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)         sum_value <= 0;
    else begin
        case (inner_loop)
            // the cycle used could be optimized
             0:         sum_value <= 0;
             1:         sum_value <= sum_value + ((weight_arr[1][1] == 0) ? 0 : weight_arr[1][1] * img_mem_q);
             2:         sum_value <= sum_value + ((weight_arr[1][2] == 0) ? 0 : weight_arr[1][2] * img_mem_q);
             3:         sum_value <= sum_value + ((weight_arr[2][2] == 0) ? 0 : weight_arr[2][2] * img_mem_q);
             4:         sum_value <= sum_value + ((weight_arr[2][1] == 0) ? 0 : weight_arr[2][1] * img_mem_q);
             5:         sum_value <= sum_value + ((weight_arr[2][0] == 0) ? 0 : weight_arr[2][0] * img_mem_q);
             6:         sum_value <= sum_value + ((weight_arr[1][0] == 0) ? 0 : weight_arr[1][0] * img_mem_q);
             7:         sum_value <= sum_value + ((weight_arr[0][0] == 0) ? 0 : weight_arr[0][0] * img_mem_q);
             8:         sum_value <= sum_value + ((weight_arr[0][1] == 0) ? 0 : weight_arr[0][1] * img_mem_q);
             9:         sum_value <= sum_value + ((weight_arr[0][2] == 0) ? 0 : weight_arr[0][2] * img_mem_q);
            default:    sum_value <= sum_value;
        endcase
    end
end

// kernel weight w/o considering boundry
assign match_position[0][0] = max_position - 16 - 1;
assign match_position[0][1] = max_position - 16 + 0;
assign match_position[0][2] = max_position - 16 + 1;
assign match_position[1][0] = max_position +  0 - 1;
assign match_position[1][1] = max_position +  0 + 0;
assign match_position[1][2] = max_position +  0 + 1;
assign match_position[2][0] = max_position + 16 - 1;
assign match_position[2][1] = max_position + 16 + 0;
assign match_position[2][2] = max_position + 16 + 1;

// kernel weight 1/9 considering boundry
always @(*) begin
    case (current_state)
        STATE_CONV_16: begin
            case (outer_loop)
                  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
                 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45:
                            weight_arr[0][0] = 0; 
                default:    weight_arr[0][0] = kernel_arr[0][0];
            endcase
        end
        STATE_CONV_8: begin
            if (img_shape<=8) begin
                case (outer_loop)
                      0,  1,  2,  3,  4,  5,  6,  7,
                     27, 26, 25, 24, 24, 23, 22, 21:
                                weight_arr[0][0] = 0;
                    default:    weight_arr[0][0] = kernel_arr[0][0];
                endcase
            end
            else                weight_arr[0][0] = kernel_arr[0][0];
        end
        STATE_CONV_4: begin
            if (img_shape<=4) begin
                case (outer_loop)
                      0,  1,  2,  3,
                     11, 10,  9:
                                weight_arr[0][0] = 0;
                    default:    weight_arr[0][0] = kernel_arr[0][0];
                endcase
            end
            else                weight_arr[0][0] = kernel_arr[0][0];
        end
        default:                weight_arr[0][0] = kernel_arr[0][0];
    endcase
end

// kernel weight 2/9 considering boundry
always @(*) begin
    case (current_state)
        STATE_CONV_16: begin
            case (outer_loop)
                  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15:
                            weight_arr[0][1] = 0; 
                default:    weight_arr[0][1] = kernel_arr[0][1];
            endcase
        end
        STATE_CONV_8: begin
            if (img_shape<=8) begin
                case (outer_loop)
                      0,  1,  2,  3,  4,  5,  6,  7:
                                weight_arr[0][1] = 0;
                    default:    weight_arr[0][1] = kernel_arr[0][1];
                endcase
            end
            else                weight_arr[0][1] = kernel_arr[0][1];
        end
        STATE_CONV_4: begin
            if (img_shape<=4) begin
                case (outer_loop)
                      0,  1,  2,  3:
                                weight_arr[0][1] = 0;
                    default:    weight_arr[0][1] = kernel_arr[0][1];
                endcase
            end
            else                weight_arr[0][1] = kernel_arr[0][1];
        end
        default:                weight_arr[0][1] = kernel_arr[0][1];
    endcase
end

// kernel weight 3/9 considering boundry
always @(*) begin
    case (current_state)
        STATE_CONV_16: begin
            case (outer_loop)
                  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
                 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30:
                            weight_arr[0][2] = 0; 
                default:    weight_arr[0][2] = kernel_arr[0][2];
            endcase
        end
        STATE_CONV_8: begin
            if (img_shape<=8) begin
                case (outer_loop)
                      0,  1,  2,  3,  4,  5,  6,  7,
                      8,  9, 10, 11, 12, 13, 14:
                                weight_arr[0][2] = 0;
                    default:    weight_arr[0][2] = kernel_arr[0][2];
                endcase
            end
            else                weight_arr[0][2] = kernel_arr[0][2];
        end
        STATE_CONV_4: begin
            if (img_shape<=4) begin
                case (outer_loop)
                      0,  1,  2,  3,
                      4,  5,  6:
                                weight_arr[0][2] = 0;
                    default:    weight_arr[0][2] = kernel_arr[0][2];
                endcase
            end
            else                weight_arr[0][2] = kernel_arr[0][2];
        end
        default:                weight_arr[0][2] = kernel_arr[0][2];
    endcase
end

// kernel weight 4/9 considering boundry
always @(*) begin
    case (current_state)
        STATE_CONV_16: begin
            case (outer_loop)
                  0,
                 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45:
                            weight_arr[1][0] = 0; 
                default:    weight_arr[1][0] = kernel_arr[1][0];
            endcase
        end
        STATE_CONV_8: begin
            if (img_shape<=8) begin
                case (outer_loop)
                      0,
                     27, 26, 25, 24, 24, 23, 22, 21:
                                weight_arr[1][0] = 0;
                    default:    weight_arr[1][0] = kernel_arr[1][0];
                endcase
            end
            else                weight_arr[1][0] = kernel_arr[1][0];
        end
        STATE_CONV_4: begin
            if (img_shape<=4) begin
                case (outer_loop)
                      0,
                     11, 10,  9:
                                weight_arr[1][0] = 0;
                    default:    weight_arr[1][0] = kernel_arr[1][0];
                endcase
            end
            else                weight_arr[1][0] = kernel_arr[1][0];
        end
        default:                weight_arr[1][0] = kernel_arr[1][0];
    endcase
end

// kernel weight 5/9 considering boundry
always @(*) begin
    weight_arr[1][1] = kernel_arr[1][1];
end

// kernel weight 6/9 considering boundry
always @(*) begin
    case (current_state)
        STATE_CONV_16: begin
            case (outer_loop)
                 15,
                 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30:
                            weight_arr[1][2] = 0; 
                default:    weight_arr[1][2] = kernel_arr[1][2];
            endcase
        end
        STATE_CONV_8: begin
            if (img_shape<=8) begin
                case (outer_loop)
                      7,
                      8,  9, 10, 11, 12, 13, 14:
                                weight_arr[1][2] = 0;
                    default:    weight_arr[1][2] = kernel_arr[1][2];
                endcase
            end
            else                weight_arr[1][2] = kernel_arr[1][2];
        end
        STATE_CONV_4: begin
            if (img_shape<=4) begin
                case (outer_loop)
                      3,
                      4,  5,  6:
                                weight_arr[1][2] = 0;
                    default:    weight_arr[1][2] = kernel_arr[1][2];
                endcase
            end
            else                weight_arr[1][2] = kernel_arr[1][2];
        end
        default:                weight_arr[1][2] = kernel_arr[1][2];
    endcase
end

// kernel weight 7/9 considering boundry
always @(*) begin
    case (current_state)
        STATE_CONV_16: begin
            case (outer_loop)
                  0,
                 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45,
                 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59:
                            weight_arr[2][0] = 0; 
                default:    weight_arr[2][0] = kernel_arr[2][0];
            endcase
        end
        STATE_CONV_8: begin
            if (img_shape<=8) begin
                case (outer_loop)
                      0,
                     14, 15, 16, 17, 18, 19, 20, 21,
                     22, 23, 24, 25, 26, 27:
                                weight_arr[2][0] = 0;
                    default:    weight_arr[2][0] = kernel_arr[2][0];
                endcase
            end
            else                weight_arr[2][0] = kernel_arr[2][0];
        end
        STATE_CONV_4: begin
            if (img_shape<=4) begin
                case (outer_loop)
                      0,
                      6,  7,  8,  9,
                     10, 11:
                                weight_arr[2][0] = 0;
                    default:    weight_arr[2][0] = kernel_arr[2][0];
                endcase
            end
            else                weight_arr[2][0] = kernel_arr[2][0];
        end
        default:                weight_arr[2][0] = kernel_arr[2][0];
    endcase
end

// kernel weight 8/9 considering boundry
always @(*) begin
    case (current_state)
        STATE_CONV_16: begin
            case (outer_loop)
                 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45:
                            weight_arr[2][1] = 0; 
                default:    weight_arr[2][1] = kernel_arr[2][1];
            endcase
        end
        STATE_CONV_8: begin
            if (img_shape<=8) begin
                case (outer_loop)
                     14, 15, 16, 17, 18, 19, 20, 21:
                                weight_arr[2][1] = 0;
                    default:    weight_arr[2][1] = kernel_arr[2][1];
                endcase
            end
            else                weight_arr[2][1] = kernel_arr[2][1];
        end
        STATE_CONV_4: begin
            if (img_shape<=4) begin
                case (outer_loop)
                      6,  7,  8,  9:
                                weight_arr[2][1] = 0;
                    default:    weight_arr[2][1] = kernel_arr[2][1];
                endcase
            end
            else                weight_arr[2][1] = kernel_arr[2][1];
        end
        default:                weight_arr[2][1] = kernel_arr[2][1];
    endcase
end

// kernel weight 9/9 considering boundry
always @(*) begin
    case (current_state)
        STATE_CONV_16: begin
            case (outer_loop)
                 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
                 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45:
                            weight_arr[2][2] = 0; 
                default:    weight_arr[2][2] = kernel_arr[2][2];
            endcase
        end
        STATE_CONV_8: begin
            if (img_shape<=8) begin
                case (outer_loop)
                      7,  8,  9, 10, 11, 12, 13, 14,
                     15, 16, 17, 18, 19, 20, 21:
                                weight_arr[2][2] = 0;
                    default:    weight_arr[2][2] = kernel_arr[2][2];
                endcase
            end
            else                weight_arr[2][2] = kernel_arr[2][2];
        end
        STATE_CONV_4: begin
            if (img_shape<=4) begin
                case (outer_loop)
                      3,  4,  5,  6,
                      7,  8,  9:
                                weight_arr[2][2] = 0;
                    default:    weight_arr[2][2] = kernel_arr[2][2];
                endcase
            end
            else                weight_arr[2][2] = kernel_arr[2][2];
        end
        default:                weight_arr[2][2] = kernel_arr[2][2];
    endcase
end

// saving maximum value & its index
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
            max_position <= 0;
            max_outvalue <= 0;
    end
    else if (current_state==STATE_IDLE) begin
            max_position <= 0;
            max_outvalue <= {1'b1,39'b0};
    end
    else if (inner_loop==10) begin
        if (sum_value > max_outvalue) begin
            max_position <= ans_mem_addr;
            max_outvalue <= sum_value;
        end
        else if ((sum_value == max_outvalue) && (ans_mem_addr < max_position)) begin
            max_position <= ans_mem_addr;
            max_outvalue <= sum_value;
        end
        else begin
            max_position <= max_position;
            max_outvalue <= max_outvalue;
        end
    end
    else begin
            max_position <= max_position;
            max_outvalue <= max_outvalue;
    end
end

// out_x & out_y calculation
always @(*) begin
    case (img_shape)
         4: begin       out_x_val = max_position[7:4] - 6; out_y_val = max_position[3:0] - 6; end 
         8: begin       out_x_val = max_position[7:4] - 4; out_y_val = max_position[3:0] - 4; end 
        default: begin  out_x_val = max_position[7:4] + 0; out_y_val = max_position[3:0] + 0; end // 16
    endcase
end

// relative index of corresponding image size used for out_img_pos
generate
    for (k=0; k<9; k=k+1) begin
        always @(*) begin
            case (img_shape)
                4: begin
                    case (out_img_pos_abs_arr[k])
                        102:        out_img_pos_arr[k] =  0;
                        103:        out_img_pos_arr[k] =  1;
                        104:        out_img_pos_arr[k] =  2;
                        105:        out_img_pos_arr[k] =  3;
                        118:        out_img_pos_arr[k] =  4;
                        119:        out_img_pos_arr[k] =  5;
                        120:        out_img_pos_arr[k] =  6;
                        121:        out_img_pos_arr[k] =  7;
                        134:        out_img_pos_arr[k] =  8;
                        135:        out_img_pos_arr[k] =  9;
                        136:        out_img_pos_arr[k] = 10;
                        137:        out_img_pos_arr[k] = 11;
                        150:        out_img_pos_arr[k] = 12;
                        151:        out_img_pos_arr[k] = 13;
                        152:        out_img_pos_arr[k] = 14;
                        153:        out_img_pos_arr[k] = 15;
                        default:    out_img_pos_arr[k] =  0;
                    endcase
                end
                8: begin
                    case (out_img_pos_abs_arr[k])
                         68:        out_img_pos_arr[k] =  0;
                         69:        out_img_pos_arr[k] =  1;
                         70:        out_img_pos_arr[k] =  2;
                         71:        out_img_pos_arr[k] =  3;
                         72:        out_img_pos_arr[k] =  4;
                         73:        out_img_pos_arr[k] =  5;
                         74:        out_img_pos_arr[k] =  6;
                         75:        out_img_pos_arr[k] =  7;
                         84:        out_img_pos_arr[k] =  8;
                         85:        out_img_pos_arr[k] =  9;
                         86:        out_img_pos_arr[k] = 10;
                         87:        out_img_pos_arr[k] = 11;
                         88:        out_img_pos_arr[k] = 12;
                         89:        out_img_pos_arr[k] = 13;
                         90:        out_img_pos_arr[k] = 14;
                         91:        out_img_pos_arr[k] = 15;
                        100:        out_img_pos_arr[k] = 16;
                        101:        out_img_pos_arr[k] = 17;
                        102:        out_img_pos_arr[k] = 18;
                        103:        out_img_pos_arr[k] = 19;
                        104:        out_img_pos_arr[k] = 20;
                        105:        out_img_pos_arr[k] = 21;
                        106:        out_img_pos_arr[k] = 22;
                        107:        out_img_pos_arr[k] = 23;
                        116:        out_img_pos_arr[k] = 24;
                        117:        out_img_pos_arr[k] = 25;
                        118:        out_img_pos_arr[k] = 26;
                        119:        out_img_pos_arr[k] = 27;
                        120:        out_img_pos_arr[k] = 28;
                        121:        out_img_pos_arr[k] = 29;
                        122:        out_img_pos_arr[k] = 30;
                        123:        out_img_pos_arr[k] = 31;
                        132:        out_img_pos_arr[k] = 32;
                        133:        out_img_pos_arr[k] = 33;
                        134:        out_img_pos_arr[k] = 34;
                        135:        out_img_pos_arr[k] = 35;
                        136:        out_img_pos_arr[k] = 36;
                        137:        out_img_pos_arr[k] = 37;
                        138:        out_img_pos_arr[k] = 38;
                        139:        out_img_pos_arr[k] = 39;
                        148:        out_img_pos_arr[k] = 40;
                        149:        out_img_pos_arr[k] = 41;
                        150:        out_img_pos_arr[k] = 42;
                        151:        out_img_pos_arr[k] = 43;
                        152:        out_img_pos_arr[k] = 44;
                        153:        out_img_pos_arr[k] = 45;
                        154:        out_img_pos_arr[k] = 46;
                        155:        out_img_pos_arr[k] = 47;
                        164:        out_img_pos_arr[k] = 48;
                        165:        out_img_pos_arr[k] = 49;
                        166:        out_img_pos_arr[k] = 50;
                        167:        out_img_pos_arr[k] = 51;
                        168:        out_img_pos_arr[k] = 52;
                        169:        out_img_pos_arr[k] = 53;
                        170:        out_img_pos_arr[k] = 54;
                        171:        out_img_pos_arr[k] = 55;
                        180:        out_img_pos_arr[k] = 56;
                        181:        out_img_pos_arr[k] = 57;
                        182:        out_img_pos_arr[k] = 58;
                        183:        out_img_pos_arr[k] = 59;
                        184:        out_img_pos_arr[k] = 60;
                        185:        out_img_pos_arr[k] = 61;
                        186:        out_img_pos_arr[k] = 62;
                        187:        out_img_pos_arr[k] = 63;
                        default:    out_img_pos_arr[k] =  0;
                    endcase
                end
                16:                 out_img_pos_arr[k] = out_img_pos_abs_arr[k];
                default:            out_img_pos_arr[k] =  0;
            endcase
        end
    end
endgenerate

// absolute index of corresponding image size used for out_img_pos
always @(*) begin
    case (img_shape)
        16: begin
            case (max_position)
                0: begin
                    // left top
                    out_img_pos_abs_arr[0] = match_position[1][1];
                    out_img_pos_abs_arr[1] = match_position[1][2];
                    out_img_pos_abs_arr[2] = match_position[2][1];
                    out_img_pos_abs_arr[3] = match_position[2][2];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                 15: begin
                    // right top
                    out_img_pos_abs_arr[0] = match_position[1][0];
                    out_img_pos_abs_arr[1] = match_position[1][1];
                    out_img_pos_abs_arr[2] = match_position[2][0];
                    out_img_pos_abs_arr[3] = match_position[2][1];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                240: begin
                    // left bot
                    out_img_pos_abs_arr[0] = match_position[0][1];
                    out_img_pos_abs_arr[1] = match_position[0][2];
                    out_img_pos_abs_arr[2] = match_position[1][1];
                    out_img_pos_abs_arr[3] = match_position[1][2];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                255: begin
                    // right bot
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[1][0];
                    out_img_pos_abs_arr[3] = match_position[1][1];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14: begin
                    // top
                    out_img_pos_abs_arr[0] = match_position[1][0];
                    out_img_pos_abs_arr[1] = match_position[1][1];
                    out_img_pos_abs_arr[2] = match_position[1][2];
                    out_img_pos_abs_arr[3] = match_position[2][0];
                    out_img_pos_abs_arr[4] = match_position[2][1];
                    out_img_pos_abs_arr[5] = match_position[2][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                 16, 32, 48, 64, 80, 96,112,128,144,160,176,192,208,224: begin
                    // left
                    out_img_pos_abs_arr[0] = match_position[0][1];
                    out_img_pos_abs_arr[1] = match_position[0][2];
                    out_img_pos_abs_arr[2] = match_position[1][1];
                    out_img_pos_abs_arr[3] = match_position[1][2];
                    out_img_pos_abs_arr[4] = match_position[2][1];
                    out_img_pos_abs_arr[5] = match_position[2][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                 31, 47, 63, 79, 95,111,127,143,159,175,191,207,223,239: begin
                    // right
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[1][0];
                    out_img_pos_abs_arr[3] = match_position[1][1];
                    out_img_pos_abs_arr[4] = match_position[2][0];
                    out_img_pos_abs_arr[5] = match_position[2][1];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                241,242,243,244,245,246,247,248,249,250,251,252,253,254: begin
                    // bot
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[0][2];
                    out_img_pos_abs_arr[3] = match_position[1][0];
                    out_img_pos_abs_arr[4] = match_position[1][1];
                    out_img_pos_abs_arr[5] = match_position[1][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                default: begin
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[0][2];
                    out_img_pos_abs_arr[3] = match_position[1][0];
                    out_img_pos_abs_arr[4] = match_position[1][1];
                    out_img_pos_abs_arr[5] = match_position[1][2];
                    out_img_pos_abs_arr[6] = match_position[2][0];
                    out_img_pos_abs_arr[7] = match_position[2][1];
                    out_img_pos_abs_arr[8] = match_position[2][2];
                end
            endcase
        end
         8: begin
            case (max_position)
                 68: begin
                    // left top
                    out_img_pos_abs_arr[0] = match_position[1][1];
                    out_img_pos_abs_arr[1] = match_position[1][2];
                    out_img_pos_abs_arr[2] = match_position[2][1];
                    out_img_pos_abs_arr[3] = match_position[2][2];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                 75: begin
                    // right top
                    out_img_pos_abs_arr[0] = match_position[1][0];
                    out_img_pos_abs_arr[1] = match_position[1][1];
                    out_img_pos_abs_arr[2] = match_position[2][0];
                    out_img_pos_abs_arr[3] = match_position[2][1];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                180: begin
                    // left bot
                    out_img_pos_abs_arr[0] = match_position[0][1];
                    out_img_pos_abs_arr[1] = match_position[0][2];
                    out_img_pos_abs_arr[2] = match_position[1][1];
                    out_img_pos_abs_arr[3] = match_position[1][2];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                187: begin
                    // right bot
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[1][0];
                    out_img_pos_abs_arr[3] = match_position[1][1];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                 69, 70, 71, 72, 73, 74: begin
                    // top
                    out_img_pos_abs_arr[0] = match_position[1][0];
                    out_img_pos_abs_arr[1] = match_position[1][1];
                    out_img_pos_abs_arr[2] = match_position[1][2];
                    out_img_pos_abs_arr[3] = match_position[2][0];
                    out_img_pos_abs_arr[4] = match_position[2][1];
                    out_img_pos_abs_arr[5] = match_position[2][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                 84,100,116,132,148,164: begin
                    // left
                    out_img_pos_abs_arr[0] = match_position[0][1];
                    out_img_pos_abs_arr[1] = match_position[0][2];
                    out_img_pos_abs_arr[2] = match_position[1][1];
                    out_img_pos_abs_arr[3] = match_position[1][2];
                    out_img_pos_abs_arr[4] = match_position[2][1];
                    out_img_pos_abs_arr[5] = match_position[2][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                 91,107,123,139,155,171: begin
                    // right
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[1][0];
                    out_img_pos_abs_arr[3] = match_position[1][1];
                    out_img_pos_abs_arr[4] = match_position[2][0];
                    out_img_pos_abs_arr[5] = match_position[2][1];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                181,182,183,184,185,186: begin
                    // bot
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[0][2];
                    out_img_pos_abs_arr[3] = match_position[1][0];
                    out_img_pos_abs_arr[4] = match_position[1][1];
                    out_img_pos_abs_arr[5] = match_position[1][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                default: begin
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[0][2];
                    out_img_pos_abs_arr[3] = match_position[1][0];
                    out_img_pos_abs_arr[4] = match_position[1][1];
                    out_img_pos_abs_arr[5] = match_position[1][2];
                    out_img_pos_abs_arr[6] = match_position[2][0];
                    out_img_pos_abs_arr[7] = match_position[2][1];
                    out_img_pos_abs_arr[8] = match_position[2][2];
                end
            endcase
        end
         4: begin
            case (max_position)
                102: begin
                    // left top
                    out_img_pos_abs_arr[0] = match_position[1][1];
                    out_img_pos_abs_arr[1] = match_position[1][2];
                    out_img_pos_abs_arr[2] = match_position[2][1];
                    out_img_pos_abs_arr[3] = match_position[2][2];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                105: begin
                    // right top
                    out_img_pos_abs_arr[0] = match_position[1][0];
                    out_img_pos_abs_arr[1] = match_position[1][1];
                    out_img_pos_abs_arr[2] = match_position[2][0];
                    out_img_pos_abs_arr[3] = match_position[2][1];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                150: begin
                    // left bot
                    out_img_pos_abs_arr[0] = match_position[0][1];
                    out_img_pos_abs_arr[1] = match_position[0][2];
                    out_img_pos_abs_arr[2] = match_position[1][1];
                    out_img_pos_abs_arr[3] = match_position[1][2];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                153: begin
                    // right bot
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[1][0];
                    out_img_pos_abs_arr[3] = match_position[1][1];
                    out_img_pos_abs_arr[4] = 0;
                    out_img_pos_abs_arr[5] = 0;
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                103,104: begin
                    // top
                    out_img_pos_abs_arr[0] = match_position[1][0];
                    out_img_pos_abs_arr[1] = match_position[1][1];
                    out_img_pos_abs_arr[2] = match_position[1][2];
                    out_img_pos_abs_arr[3] = match_position[2][0];
                    out_img_pos_abs_arr[4] = match_position[2][1];
                    out_img_pos_abs_arr[5] = match_position[2][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                118,134: begin
                    // left
                    out_img_pos_abs_arr[0] = match_position[0][1];
                    out_img_pos_abs_arr[1] = match_position[0][2];
                    out_img_pos_abs_arr[2] = match_position[1][1];
                    out_img_pos_abs_arr[3] = match_position[1][2];
                    out_img_pos_abs_arr[4] = match_position[2][1];
                    out_img_pos_abs_arr[5] = match_position[2][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                121,137: begin
                    // right
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[1][0];
                    out_img_pos_abs_arr[3] = match_position[1][1];
                    out_img_pos_abs_arr[4] = match_position[2][0];
                    out_img_pos_abs_arr[5] = match_position[2][1];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                151,152: begin
                    // bot
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[0][2];
                    out_img_pos_abs_arr[3] = match_position[1][0];
                    out_img_pos_abs_arr[4] = match_position[1][1];
                    out_img_pos_abs_arr[5] = match_position[1][2];
                    out_img_pos_abs_arr[6] = 0;
                    out_img_pos_abs_arr[7] = 0;
                    out_img_pos_abs_arr[8] = 0;
                end
                default: begin
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[0][2];
                    out_img_pos_abs_arr[3] = match_position[1][0];
                    out_img_pos_abs_arr[4] = match_position[1][1];
                    out_img_pos_abs_arr[5] = match_position[1][2];
                    out_img_pos_abs_arr[6] = match_position[2][0];
                    out_img_pos_abs_arr[7] = match_position[2][1];
                    out_img_pos_abs_arr[8] = match_position[2][2];
                end
            endcase
        end
        default: begin
                    out_img_pos_abs_arr[0] = match_position[0][0];
                    out_img_pos_abs_arr[1] = match_position[0][1];
                    out_img_pos_abs_arr[2] = match_position[0][2];
                    out_img_pos_abs_arr[3] = match_position[1][0];
                    out_img_pos_abs_arr[4] = match_position[1][1];
                    out_img_pos_abs_arr[5] = match_position[1][2];
                    out_img_pos_abs_arr[6] = match_position[2][0];
                    out_img_pos_abs_arr[7] = match_position[2][1];
                    out_img_pos_abs_arr[8] = match_position[2][2];
        end
    endcase
end

// action signals
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i=0;i<9;i=i+1) begin
            action_arr[i] <= 0;
        end
    end
    else if (in_valid_2) action_arr[cnt] <= action;
    else begin
        for (i=0;i<9;i=i+1) begin
            action_arr[i] <= action_arr[i];
        end
    end
end
endmodule

// REORDER TABLE
// #    First       Second
// 0    row S->L    col S->L
// 1    row S->L    col L->S
// 2    row L->S    col S->L
// 3    row L->S    col L->S
// 4    col S->L    row S->L
// 5    col S->L    row L->S
// 6    col L->S    row S->L
// 7    col L->S    row L->S

// #        Current shape           Start Index             Direction (Row / Col)    
// 0 / 4    4 / 8 / 16      ( 6, 6) / ( 4, 4) / ( 0, 0)         (+1,+1)
// 1 / 5    4 / 8 / 16      ( 6, 9) / ( 4,11) / ( 0,15)         (+1,-1)
// 2 / 6    4 / 8 / 16      ( 9, 6) / (11, 4) / (15, 0)         (-1,+1)
// 3 / 7    4 / 8 / 16      ( 9, 9) / (11,11) / (15,15)         (-1,-1)

// Horizontal Flip  Vertical Flip   Left-diagonal Flip  Right-diagonal Flip
//  0 <--> 1         0 <--> 2           0 <--> 7            0 <--> 4
//  2 <--> 3         1 <--> 3           1 <--> 6            1 <--> 5
//  4 <--> 6         4 <--> 5           2 <--> 5            2 <--> 6
//  5 <--> 7         6 <--> 7           3 <--> 4            3 <--> 7

// CONVOLUTION ORDER TABLE
//   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
//  59  60  61  62  63  64  65  66  67  68  69  70  71  72  73  16
//  58  11  12  13  14  15  16  17  18  19  20  21  22  23  74  17
//  57  10  55  56  57  58  59  60  61  62  63  64  65  24  75  18
//  56  09  54  91                                  66  25  76  19
//  55  08  53  90                                  67  26  77  20
//  54  07  52  88                                  68  27  78  21
//  53  06  51  88                                  69  28  79  22
//  52  05  50  87                                  70  29  80  23
//  51  04  49  86                                  71  30  81  24
//  50  03  48  85                                  72  31  82  25
//  49  02  47  84                                  73  32  83  26
//  48  01  46  83  82  81  80  79  78  76  76  75  74  33  84  27
//  47  00  45  44  43  42  41  40  39  38  37  36  35  34  85  28
//  46  99  98  97  96  95  94  93  92  91  90  89  88  87  86  29
//  45  44  43  42  41  40  39  38  37  36  35  34  33  32  31  30

//                   0   1   2   3   4   5   6   7
//                  27  28  29  30  31  32  33   8
//                  26  47                  34   9
//                  25  46                  35  10
//                  24  45                  36  11
//                  23  44                  37  12
//                  22  43  42  41  40  39  38  13
//                  21  20  29  18  17  16  15  14

//                           0   1   2   3
//                          11  12  13   4
//                          10  15  14   5
//                           9   8   7   6

// MAXPOOLING ORDER TABLE
// Read 4
//   0   1   4   5
//   3   2   7   6
//  12  13   8   9
//  15  14  11  10

// Write 4
//       0   1
//       3   2

// Read 8
//   0   1   4   5   8   9  12  13
//   3   2   7   6  11  10  15  14
//  44  45                  16  17
//  47  46                  19  18
//  40  41                  20  21
//  43  42                  23  22
//  36  37  32  33  28  29  24  25
//  39  38  35  34  31  30  27  26

// Write 8
//           0   1   2   3
//          11           4
//          10           5
//           9   8   7   6

// Read 16
//   0   1   4   5   8   9  12  13  16  17  20  21  24  25  28  29
//   3   2   7   6  11  10  15  14  19  18  23  22  27  26  31  30
//  08  09  12  13  16  17  20  21  24  25  28  29  32  33  32  33
//  11  10  15  14  19  18  23  22  27  26  31  30  35  34  35  34
//  04  05  88  89                                  36  37  36  37
//  07  06  91  90                                  39  38  39  38
//  00  01  84  85                                  40  41  40  41
//  03  02  87  86                                  43  42  43  42
//  96  97  80  81                                  44  45  44  45
//  99  98  83  82                                  47  46  47  46
//  92  93  76  77                                  48  49  48  49
//  95  94  79  78                                  51  50  51  50
//  88  89  72  73  68  69  64  65  60  61  56  57  52  53  52  53
//  91  90  75  74  71  70  67  66  63  62  59  58  55  54  55  54
//  84  85  80  81  76  77  72  73  68  69  64  65  60  61  56  57
//  87  86  83  82  79  78  75  74  71  70  67  66  63  62  59  58

// Write 16
//                   0   1   2   3   4   5   6   7
//                  27  28  29  30  31  32  33   8
//                  26  47                  34   9
//                  25  46                  35  10
//                  24  45                  36  11
//                  23  44                  37  12
//                  22  43  42  41  40  39  38  13
//                  21  20  19  18  17  16  15  14

// ZOOMIN ORDER TABLE
// Read 8
//                   0   1   2   3   4   5   6   7
//                  27  28  29  30  31  32  33   8
//                  26  47                  34   9
//                  25  46                  35  10
//                  24  45                  36  11
//                  23  44                  37  12
//                  22  43  42  41  40  39  38  13
//                  21  20  19  18  17  16  15  14

// Write 8
//   0   1   4   5   8   9  12  13  16  17  20  21  24  25  28  29
//   3   2   7   6  11  10  15  14  19  18  23  22  27  26  31  30
//  08  09  12  13  16  17  20  21  24  25  28  29  32  33  32  33
//  11  10  15  14  19  18  23  22  27  26  31  30  35  34  35  34
//  04  05  88  89                                  36  37  36  37
//  07  06  91  90                                  39  38  39  38
//  00  01  84  85                                  40  41  40  41
//  03  02  87  86                                  43  42  43  42
//  96  97  80  81                                  44  45  44  45
//  99  98  83  82                                  47  46  47  46
//  92  93  76  77                                  48  49  48  49
//  95  94  79  78                                  51  50  51  50
//  88  89  72  73  68  69  64  65  60  61  56  57  52  53  52  53
//  91  90  75  74  71  70  67  66  63  62  59  58  55  54  55  54
//  84  85  80  81  76  77  72  73  68  69  64  65  60  61  56  57
//  87  86  83  82  79  78  75  74  71  70  67  66  63  62  59  58

// Read 4
//           0   1   2   3
//          11  12  13   4
//          10  15  14   5
//           9   8   7   6

// Write 4
//   0   1   4   5   8   9  12  13
//   3   2   7   6  11  10  15  14
//  44  45  48  49  52  53  16  17
//  47  46  51  50  55  54  19  18
//  40  41  60  61  56  57  20  21
//  43  42  63  62  59  58  23  22
//  36  37  32  33  28  29  24  25
//  39  38  35  34  31  30  27  26

// SHORTCUT ORDER TABLE
// Read / Write
//   0   1   2   3
//  11  12  13   4
//  10  15  14   5
//   9   8   7   6

// supplementary: boundary
//   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
//  16                                                          31
//  32                                                          47
//  48                                                          63
//  64              68  69  70  71  72  73  74  75              79
//  80              84                          91              95
//  96             100     102 103 104 105     107             111
// 112             116     118         121     123             127
// 128             132     134         137     139             143
// 144             148     150 151 152 153     155             159
// 160             164                         171             175
// 176             180 181 182 183 184 185 186 187             191
// 192                                                         207
// 208                                                         223
// 224                                                         239
// 240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255

// supplementary: fully order table
//   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
//  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31
//  32  33  34  35  36  37  38  39  40  41  42  43  44  45  46  47
//  48  49  50  51  52  53  54  55  56  57  58  59  60  61  62  63
//  64  65  66  67  68  69  70  71  72  73  74  75  76  77  78  79
//  80  81  82  83  84  85  86  87  88  89  90  91  92  93  94  95
//  96  97  98  99 100 101 102 103 104 105 106 107 108 109 110 111
// 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127
// 128 129 130 131 132 133 134 135 136 137 138 139 140 141 142 143
// 144 145 146 147 148 149 150 151 152 153 154 155 156 157 158 159
// 160 161 162 163 164 165 166 167 168 169 170 171 172 173 174 175
// 176 177 178 179 180 181 182 183 184 185 186 187 188 189 190 191
// 192 193 194 195 196 197 198 199 200 201 202 203 204 205 206 207
// 208 209 210 211 212 213 214 215 216 217 218 219 220 221 222 223
// 224 225 226 227 228 229 230 231 232 233 234 235 236 237 238 239
// 240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255

//                  68  69  70  71  72  73  74  75 
//                  84  85  86  87  88  89  90  91 
//                 100 101 102 103 104 105 106 107
//                 116 117 118 119 120 121 122 123
//                 132 133 134 135 136 137 138 139
//                 148 149 150 151 152 153 154 155
//                 164 165 166 167 168 169 170 171
//                 180 181 182 183 184 185 186 187

//                         102 103 104 105
//                         118 119 120 121
//                         134 135 136 137
//                         150 151 152 153

// ================================DRAFT NOT NECESSARY CORRECT===================================== //
// Output Operation (?)
// Cycle    Operation
//   0      Set 1st read signal
//   1      Get 1st data during the middle of cycle
//   2      Output   1st out signal
//   3      Output   2nd out signal
//   4      Output   3rd out signal
//  ...
//  17      Output  16th out signal
//  65      Output  64th out signal
// 257      Output 256th out signal

// Convolution Operation (4/8/16 --> 4/8/16)
// Cycle    Operation
//  0       Set 1st read signal
//  1       Get 1st data
//  2       Get 2nd data
//  3       Get 3rd data
//  4       Get 4th data
//  5       Get 5th data
//  6       Get 6th data
//  7       Get 7th data
//  8       Get 8th data
//  9       Get 9th data
// 10       Idle for calculation
// 11       Set write signal

// Max Pooling Operation (4/8/16 --> 4/4/8) (?)
// Cycle    Operation
//  0       Set 1st r_addr_sig
//  1       Set 1st read signal
//  2       Get 1st data
//  3       Get 2nd data
//  4       Get 3rd data
//  5       Get 4th data
//  6       Set write signal

// Zoom-in Operation (4/8/16 --> 8/16/16) (?)
// Cycle    Operation
//  0       Set 1st r_addr_sig
//  1       Set 1st read signal
//  2       Get 1st data
//  3       Set 1st write signal
//  4       Set 2nd write signal
//  5       Set 3rd write signal
//  6       Set 4th write signal

// Shortcut Operation (4/8/16 --> 4/4/4) (?)
// Cycle    Operation
//  0       Set read signal
//  1       Get data
//  2       Set write signal