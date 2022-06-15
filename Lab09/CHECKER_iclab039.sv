//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//
//   File Name   : CHECKER.sv
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module Checker(input clk, INF.CHECKER inf);
import usertype::*;

// Create a covergroup including coverpoint inf.out_info[31:28] and inf.out_info[27:24] (Player Pokemon info when action is not Attack; Defender Pokemon info when action is Attack).
// The bins of inf.out_info[31:28] needs to be No_stage, Lowest, Middle and Highest, respectively. 
// The bins of inf.out_info[27:24] needs to be No_type, Grass, Fire, Water, Electric, Normal, respectively. 
// Each bin should be hit at least 20 times. (sample the value at negedge clk when inf.out_valid is high) (Note: We will use exactly word like “Lowest” instead of number “4’d1”)
// Minimum Actions: 20*4, 20*5 = 80, 100
covergroup Coverage_1 @(negedge clk iff inf.out_valid);
    option.name = "out_info_signal";
    option.comment = "Pokemon stage and type";
    option.at_least = 20;
    option.per_instance = 1;

    coverpoint inf.out_info[31:28] {
            bins stage_1 = {No_stage};
            bins stage_2 = {Lowest};
            bins stage_3 = {Middle};
            bins stage_4 = {Highest};
    }

    coverpoint inf.out_info[27:24] {
            bins type_1 = {No_type};
            bins type_2 = {Grass};
            bins type_3 = {Fire};
            bins type_4 = {Water};
            bins type_5 = {Electric};
            bins type_6 = {Normal};
    }
endgroup

// Create a covergroup including coverpoint inf.D.d_id[0] (means 0~7 bits of input signal D when typing your ID) with auto_bin_max = 256.
// (means that you need to divide the inf.D.d_id[0] signal into 256 bins averagely).
// And each bin has to be hit at least 1 time. (sample the value at posedge clk when id_valid is high)
// Minimum Actions: 256
covergroup Coverage_2 @(posedge clk iff inf.id_valid);
    option.name = "d_id_signal";
    option.comment = "Player ID";
    option.at_least = 1;
    option.auto_bin_max = 256;
    option.per_instance = 1;

    coverpoint inf.D.d_id[0];
endgroup

// Create a covergroup including coverpoint inf.D.d_act[0] (means 0~3 bits of input signal D when typing your action).
// There are six actions for inf.D.d_act[0]: Buy, Sell, Deposit, Check, Use_item, Attack.
// Create the transition bins from one action to itself or others. such as: Buy to Buy, Buy to Sell, Buy to Deposit, Buy to Check, Buy to Use_item, Buy to Attack and so on.
// There are total 36 transition bins. Each transition bin should be hit at least 10 times. (sample the value at posedge clk when act_valid is high).
// Minimum Actions: 36*10 = 360
covergroup Coverage_3 @(posedge clk iff inf.act_valid);
    option.name = "d_act_signal";
    option.comment = "Action";
    option.at_least = 10;
    option.per_instance = 1;

    coverpoint inf.D.d_act[0] {
            bins tran_act[] = (
                    Buy, Sell, Deposit, Check, Use_item, Attack =>
                    Buy, Sell, Deposit, Check, Use_item, Attack
            );
    }
endgroup

// Create a covergroup including coverpoints inf.complete. 
// The bins of inf.complete need to be 0 and 1, and each bin should be hit at least 200 times. (sample the value at negedge clk when inf.out_valid is high)
// Minimum Actions: 200*2 = 400
covergroup Coverage_4 @(negedge clk iff inf.out_valid);
    option.name = "complete_signal";
    option.comment = "Complete";
    option.at_least = 200;
    option.per_instance = 1;

    coverpoint inf.complete;
endgroup

// Create a covergroup including coverpoint inf.err_msg. Every case of inf.err_msg except No_Err should occur at least 20 times. (sample the value at negedge clk when inf.out_valid is high)
// Minimum Actions: 20*7 = 140
covergroup Coverage_5 @(negedge clk iff inf.out_valid);
    option.name = "err_msg_signal";
    option.comment = "Error Message";
    option.at_least = 20;
    option.per_instance = 1;

    coverpoint inf.err_msg {
            bins err_1 = {Already_Have_PKM};
            bins err_2 = {Out_of_money};
            bins err_3 = {Bag_is_full};
            bins err_4 = {Not_Having_PKM};
            bins err_5 = {Has_Not_Grown};
            bins err_6 = {Not_Having_Item};
            bins err_7 = {HP_is_Zero};
    }
endgroup

Coverage_1 cov_inst_1 = new();  // Minimum Actions: 20*4, 20*5 = 80, 100
Coverage_2 cov_inst_2 = new();  // Minimum Actions: 256
Coverage_3 cov_inst_3 = new();  // Minimum Actions: 36*10 = 360
Coverage_4 cov_inst_4 = new();  // Minimum Actions: 200*2 = 400
Coverage_5 cov_inst_5 = new();  // Minimum Actions: 20*7 = 140

parameter SHOW_COVERAGE = 0;

final begin
    if (SHOW_COVERAGE) begin
        $display("Instance Coverage_1 is %f",cov_inst_1.get_coverage());
        $display("Instance Coverage_2 is %f",cov_inst_2.get_coverage());
        $display("Instance Coverage_3 is %f",cov_inst_3.get_coverage());
        $display("Instance Coverage_4 is %f",cov_inst_4.get_coverage());
        $display("Instance Coverage_5 is %f",cov_inst_5.get_coverage());
    end

end

//************************************ below assertion is to check your pattern ***************************************** 

// ASSERTION 1.      All outputs signals (including pokemon.sv and bridge.sv) should be zero after reset.
// SPEC 1.           After rst_n, all the output signals (both pokemon and bridge) should be set to 0.
logic init_rst;
always_ff @(negedge inf.rst_n) begin
    if (!inf.rst_n) init_rst <= 1;
end

assert property ( @(posedge inf.rst_n)  (
    (init_rst) |-> (
        (inf.out_valid === 0)       &&     // pokemon system output
        (inf.err_msg === 0)         &&
        (inf.complete === 0)        &&
        (inf.out_info === 0)        &&
        (inf.C_addr === 0)          &&
        (inf.C_data_w === 0)        &&
        (inf.C_in_valid === 0)      &&
        (inf.C_r_wb === 0)          &&

        (inf.C_out_valid === 0)     &&     // bridge output
        (inf.C_data_r === 0)        &&
        (inf.AR_VALID === 0)        &&
        (inf.AR_ADDR === 0)         &&
        (inf.R_READY === 0)         &&
        (inf.AW_VALID === 0)        &&
        (inf.AW_ADDR === 0)         &&
        (inf.W_VALID === 0)         &&
        (inf.W_DATA === 0)          &&
        (inf.B_READY === 0)
    )
) )
else begin
    $display("Assertion 1 is violated");
    // assertion_1_info;
    $fatal;
end 

// ASSERTION 2.      If action is completed, err_msg should be 4’b0.
// SPEC 17.          If action complete, complete should be high and err_msg should be 4’b0.
assert property ( @(posedge clk) ( (inf.out_valid === 1) && (inf.complete === 1) ) |-> (inf.err_msg === 4'b0) )
else begin
    $display("Assertion 2 is violated");
    // assertion_2_info;
    $fatal;
end

// ASSERTION 3.      If action is not completed, out_info should be 64’b0.
// SPEC 18.          If action not complete, complete should be low, err_msg should be corresponding value and out_info should be 64’b0.
assert property ( @(posedge clk) ( (inf.out_valid === 1) && (inf.complete === 0) ) |-> (inf.out_info === 64'b0) )
else begin
    $display("Assertion 3 is violated");
    // assertion_3_info;
    $fatal;
end

// ASSERTION 4.      The gap between each input valid is at least 1 cycle and at most 5 cycles.
// SPEC -1.          None

logic start_action;  // identify the gap between the falling edge of out_valid and the rising edge of act_valid for id_valid signal
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             start_action <= 0;
    else if (inf.out_valid)     start_action <= 0;
    else if (inf.act_valid)     start_action <= 1;
    else                        start_action <= start_action;
end

// Change Player --> Action
assert property ( @(posedge clk) ( ((!start_action) && (inf.id_valid)) |=> (##[1:5] inf.act_valid) ) )
else begin
    $display("Assertion 4 is violated");
    // assertion_4_info;
    $fatal;
end

// Buy        --> Pokemon / Item
assert property ( @(posedge clk) (inf.act_valid && (inf.D.d_act[0] == Buy))         |=> ##[1:5] (inf.item_valid || inf.type_valid) )
else begin
    $display("Assertion 4 is violated");
    // assertion_4_info;
    $fatal;
end

// Sell       --> Pokemon / Item
assert property ( @(posedge clk) (inf.act_valid && (inf.D.d_act[0] == Sell))        |=> ##[1:5] (inf.item_valid || inf.type_valid) )
else begin
    $display("Assertion 4 is violated");
    // assertion_4_info;
    $fatal;
end

// Deposit    --> Money
assert property ( @(posedge clk) (inf.act_valid && (inf.D.d_act[0] == Deposit))     |=> ##[1:5] (inf.amnt_valid) )
else begin
    $display("Assertion 4 is violated");
    // assertion_4_info;
    $fatal;
end

// Check, no arguments should be checked

// Use_item   --> Item
assert property ( @(posedge clk) (inf.act_valid && (inf.D.d_act[0] == Use_item))    |=> ##[1:5] (inf.item_valid) )
else begin
    $display("Assertion 4 is violated");
    // assertion_4_info;
    $fatal;
end

// Attack     --> Player
assert property ( @(posedge clk) (inf.act_valid && (inf.D.d_act[0] == Attack))      |=> ##[1:5] (inf.id_valid) )
else begin
    $display("Assertion 4 is violated");
    // assertion_4_info;
    $fatal;
end

// ASSERTION 5.      All input valid signals won’t overlap with each other.
// SPEC 12.          The 5 input valid signals won’t overlap with each other.
assert property ( @(posedge clk) !(
    (inf.id_valid        && inf.act_valid)    ||
    (inf.id_valid        && inf.item_valid)   ||
    (inf.id_valid        && inf.type_valid)   ||
    (inf.id_valid        && inf.amnt_valid)   ||

    (inf.act_valid       && inf.id_valid)     ||
    (inf.act_valid       && inf.item_valid)   ||
    (inf.act_valid       && inf.type_valid)   ||
    (inf.act_valid       && inf.amnt_valid)   ||

    (inf.item_valid      && inf.id_valid)     ||
    (inf.item_valid      && inf.act_valid)    ||
    (inf.item_valid      && inf.type_valid)   ||
    (inf.item_valid      && inf.amnt_valid)   ||

    (inf.type_valid      && inf.id_valid)     ||
    (inf.type_valid      && inf.act_valid)    ||
    (inf.type_valid      && inf.item_valid)   ||
    (inf.type_valid      && inf.amnt_valid)   ||

    (inf.amnt_valid      && inf.id_valid)     ||
    (inf.amnt_valid      && inf.act_valid)    ||
    (inf.amnt_valid      && inf.item_valid)   ||
    (inf.amnt_valid      && inf.type_valid)
)) 
else begin
    $display("Assertion 5 is violated");
    // assertion_5_info;
    $fatal;
end

// ASSERTION 6.      Out_valid can only be high for exactly one cycle.
// SPEC 14.          Out_valid can only be high for exactly one cycle.
assert property ( @(posedge clk) ((inf.out_valid === 1) |=> (inf.out_valid === 0)) ) 
else begin
    $display("Assertion 6 is violated");
    // assertion_6_info;
    $fatal;
end

// ASSERTION 7.      Next operation will be valid 2-10 cycles after out_valid fall.
// SPEC 19.          Next operation will be valid 2-10 cycles after out_valid fall.
assert property ( @(posedge clk) (inf.out_valid === 1) |=> ((!(inf.id_valid || inf.act_valid)) ##[1:9] (inf.id_valid || inf.act_valid)) )
else begin
    $display("Assertion 7 is violated");
    // assertion_7_info;
    $fatal;
end

// ASSERTION 8.      Latency should be less than 1200 cycles for each operation.
// DESIGN CONSTRAINT Latency should be less than 1200 cycles for each operation.
// Buy        --> Pokemon / Item
Action current_action;
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             current_action <= No_action;
    else if (inf.act_valid)     current_action <= inf.D.d_act[0];
    else if (inf.out_valid)     current_action <= No_action;
    else                        current_action <= current_action;
end

assert property ( @(posedge clk) ( ((current_action == Buy) && (inf.item_valid || inf.type_valid)) |-> (##[1:1200] inf.out_valid) ) )
else begin
    $display("Assertion 8 is violated");
    // assertion_8_info;
    $fatal;
end

// Sell       --> Pokemon / Item
assert property ( @(posedge clk) ( ((current_action == Sell) && (inf.item_valid || inf.type_valid)) |-> (##[1:1200] inf.out_valid) ) )
else begin
    $display("Assertion 8 is violated");
    // assertion_8_info;
    $fatal;
end

// Deposit    --> Money
assert property ( @(posedge clk) ( ((current_action == Deposit) && (inf.amnt_valid)) |-> (##[1:1200] inf.out_valid) ) )
else begin
    $display("Assertion 8 is violated");
    // assertion_8_info;
    $fatal;
end

// Check
assert property ( @(posedge clk) ( (current_action == Check) |-> (##[1:1200] inf.out_valid) ) )
else begin
    $display("Assertion 8 is violated");
    // assertion_8_info;
    $fatal;
end

// Use_item   --> Item
assert property ( @(posedge clk) ( ((current_action == Use_item) && (inf.item_valid)) |-> (##[1:1200] inf.out_valid) ) )
else begin
    $display("Assertion 8 is violated");
    // assertion_8_info;
    $fatal;
end

// Attack     --> Player
assert property ( @(posedge clk) ( ((current_action == Attack) && (inf.id_valid)) |-> (##[1:1200] inf.out_valid) ) )
else begin
    $display("Assertion 8 is violated");
    // assertion_8_info;
    $fatal;
end

// SPEC  8.          C_in_valid can only be high for one cycle, and can’t be pulled high again before C_out_valid.
// assert property ( @(posedge clk) ((inf.C_in_valid) |=> (!inf.C_in_valid throughout inf.C_out_valid [->1]) ) )
// else begin
//     $display("SPEC 8.              C_in_valid can only be high for one cycle, and can’t be pulled high again before C_out_valid.");
//     $fatal;
// end

// SPEC 13.          Out_valid cannot overlap with the 5 input valid signals.
// assert property ( @(posedge clk) !(
//     (inf.out_valid && inf.id_valid)    ||
//     (inf.out_valid && inf.act_valid)   ||
//     (inf.out_valid && inf.item_valid)  ||
//     (inf.out_valid && inf.type_valid)  ||
//     (inf.out_valid && inf.amnt_valid)
// )) 
// else begin
//     $display("SPEC 13.             Out_valid cannot overlap with the 5 input valid signals.");
//     $display("inf.out_valid %b",inf.out_valid);
//     $display("inf.id_valid %b",inf.id_valid);
//     $display("inf.act_valid %b",inf.act_valid);
//     $display("inf.item_valid %b",inf.item_valid);
//     $display("inf.type_valid %b",inf.type_valid);
//     $display("inf.amnt_valid %b",inf.amnt_valid);
//     $fatal;
// end

// SPEC 15.          Out_valid can only be high after given all necessary input valid signals.
// Not specified

task assertion_1_info; begin
    $display("Assertion 1.         All outputs signals (including pokemon.sv and bridge.sv) should be zero after reset.");
    $display("SPEC 1.              After rst_n, all the output signals (both pokemon and bridge) should be set to 0.");
    
    if (inf.out_valid !== 0)       $display("inf.out_valid %b",inf.out_valid);
    if (inf.err_msg !== 0)         $display("inf.err_msg %b",inf.err_msg);
    if (inf.complete !== 0)        $display("inf.complete %b",inf.complete);
    if (inf.out_info !== 0)        $display("inf.out_info %b",inf.out_info);
    if (inf.C_addr !== 0)          $display("inf.C_addr %b",inf.C_addr);
    if (inf.C_data_w !== 0)        $display("inf.C_data_w %b",inf.C_data_w);
    if (inf.C_in_valid !== 0)      $display("inf.C_in_valid %b",inf.C_in_valid);
    if (inf.C_r_wb !== 0)          $display("inf.C_r_wb %b",inf.C_r_wb);

    if (inf.C_out_valid !== 0)     $display("inf.C_out_valid %b",inf.C_out_valid);
    if (inf.C_data_r !== 0)        $display("inf.C_data_r %b",inf.C_data_r);
    if (inf.AR_VALID !== 0)        $display("inf.AR_VALID %b",inf.AR_VALID);
    if (inf.AR_ADDR !== 0)         $display("inf.AR_ADDR %b",inf.AR_ADDR);
    if (inf.R_READY !== 0)         $display("inf.R_READY %b",inf.R_READY);
    if (inf.AW_VALID !== 0)        $display("inf.AW_VALID %b",inf.AW_VALID);
    if (inf.AW_ADDR !== 0)         $display("inf.AW_ADDR %b",inf.AW_ADDR);
    if (inf.W_VALID !== 0)         $display("inf.W_VALID %b",inf.W_VALID);
    if (inf.W_DATA !== 0)          $display("inf.W_DATA %b",inf.W_DATA);
    if (inf.B_READY !== 0)         $display("inf.B_READY %b",inf.B_READY);
end endtask

task assertion_2_info; begin
    $display("Assertion 2.         If action is completed, err_msg should be 4’b0.");
    $display("SPEC 17.             If action complete, complete should be high and err_msg should be 4’b0.");

    $display("inf.out_valid %b",inf.out_valid);
    $display("inf.complete %b",inf.complete);
    $display("inf.err_msg %b",inf.err_msg);
end endtask

task assertion_3_info; begin
    $display("Assertion 3.         If action is not completed, out_info should be 64’b0.");
    $display("SPEC 18.             If action not complete, complete should be low, err_msg should be corresponding value and out_info should be 64’b0.");

    $display("inf.out_valid %b",inf.out_valid);
    $display("inf.complete %b",inf.complete);
    $display("inf.out_info %b",inf.out_info);
end endtask

task assertion_4_info; begin
    $display("Assertion 4.         The gap between each input valid is at least 1 cycle and at most 5 cycles.");
    $display("SPEC -1.             None");
end endtask

task assertion_5_info; begin
    $display("Assertion 5.         All input valid signals won’t overlap with each other.");
    $display("SPEC 12.             The 5 input valid signals won’t overlap with each other.");

    $display("inf.id_valid %b",inf.id_valid);
    $display("inf.act_valid %b",inf.act_valid);
    $display("inf.item_valid %b",inf.item_valid);
    $display("inf.type_valid %b",inf.type_valid);
    $display("inf.amnt_valid %b",inf.amnt_valid);
end endtask

task assertion_6_info; begin
    $display("Assertion 6.         Out_valid can only be high for exactly one cycle.");
    $display("SPEC 14.             Out_valid can only be high for exactly one cycle.");
end endtask

task assertion_7_info; begin
    $display("Assertion 7.         Next operation will be valid 2-10 cycles after out_valid fall.");
    $display("SPEC 19.             Next operation will be valid 2-10 cycles after out_valid fall.");
end endtask

task assertion_8_info; begin
    $display("Assertion 8.         Latency should be less than 1200 cycles for each operation.");
    $display("Design Contraint.    Your latency should be less than 1200 cycles for each operation.");
end endtask

endmodule