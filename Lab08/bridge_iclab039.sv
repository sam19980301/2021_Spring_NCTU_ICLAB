module bridge(input clk, INF.bridge_inf inf);

// ===============================================================
//                           Logic
// ===============================================================
// FSM
BRIDGE_State current_state, next_state;

// Input Signals
logic [ 7:0]    addr;
logic [63:0]    data;


// ===============================================================
//                           Design
// ===============================================================

// FSM
// current state
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) current_state <= AXI_IDLE;
    else            current_state <= next_state;
end

// next state
always_comb begin
    case (current_state)
        AXI_IDLE: begin
            if (inf.C_in_valid) begin
                if (inf.C_r_wb) next_state = AXI_R_ADDR;    // Read  from DRAM
                else            next_state = AXI_W_ADDR;    // Write from DRAM
            end
            else                next_state = current_state;
        end
        AXI_W_ADDR: begin
            if (inf.AW_READY)   next_state = AXI_W_DATA;
            else                next_state = current_state;
        end
        AXI_W_DATA: begin
            if (inf.W_READY)    next_state = AXI_W_RESP;
            else                next_state = current_state;
        end
        AXI_W_RESP: begin
            if (inf.B_VALID)    next_state = AXI_OUTPUT;
            else                next_state = current_state;
        end
        AXI_R_ADDR: begin
            if (inf.AR_READY)   next_state = AXI_R_DATA;
            else                next_state = current_state;
        end
        AXI_R_DATA: begin
            if (inf.R_VALID)    next_state = AXI_OUTPUT;
            else                next_state = current_state;
        end
        AXI_OUTPUT:             next_state = AXI_IDLE;
        default:                next_state = current_state;
    endcase
end

// Output Signals
// Pokemon System Side
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)                         inf.C_out_valid <= 0;
    else if (current_state == AXI_OUTPUT)   inf.C_out_valid <= 1; // (next_state == AXI_OUTPUT) may save 1 cycle
    else                                    inf.C_out_valid <= 0;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)         inf.C_data_r <= 0;
    else if (inf.R_VALID)   inf.C_data_r <= inf.R_DATA;
    else                    inf.C_data_r <= inf.C_data_r;
end

// AXI (DRAM) Side
// Read Address Channel
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             inf.AR_VALID <= 0;
    else                        inf.AR_VALID <= (current_state == AXI_R_ADDR);
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             inf.AR_ADDR <= 0;
    else                        inf.AR_ADDR <= {1'b1, 5'b0, addr, 3'b0};
end


// Read Data Channel
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             inf.R_READY <= 0;
    else                        inf.R_READY <= 1;
end

// Write Address Channel
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             inf.AW_VALID <= 0;
    else                        inf.AW_VALID <= (current_state == AXI_W_ADDR);
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             inf.AW_ADDR <= 0;
    else                        inf.AW_ADDR <= {1'b1, 5'b0, addr, 3'b0};
end


// Write Data Channel
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             inf.W_VALID <= 0;
    else                        inf.W_VALID <= 1;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             inf.W_DATA <= 0;
    else                        inf.W_DATA <= data;
end


// Write Response Channel
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             inf.B_READY <= 0;
    else                        inf.B_READY <= 1;
end


// Input Signals
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             addr <= 0;
    else if (inf.C_in_valid)    addr <= inf.C_addr;
    else                        addr <= addr;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             data <= 0;
    else if (inf.C_in_valid)    data <= inf.C_data_w;
    else                        data <= data;
end

endmodule