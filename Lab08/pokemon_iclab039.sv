module pokemon(input clk, INF.pokemon_inf inf);
import usertype::*;

// ===============================================================
//                      Parameter Declaration 
// ===============================================================


// ===============================================================
//                           Logic
// ===============================================================
// FSM
PKM_State   current_state,        next_state;           // Pokemon System FSM
AXI_State   current_axi_state,    next_axi_state;       // AXI FSM      (Attacker Player)
AXI_State   current_axi_substate, next_axi_substate;    // AXI Sub FSM  (Defender Player)

logic       finish_load_def;                            // finish loading defender information
logic       change_user;                                // changing user before action
logic       duplicate_player;                           // the main player is same as last defender (swap data)

// Input Signals
// User (Pattern) Side
Money               deposit_money;
Player_id_expand    player_id;
Action              action;
PKM_Type            pkm_type;
Item                item;
Category            category;

Player_id_expand    def_player_id;
Player_id           last_player_id;                     // buffer signals used for defending player

// AXI Side
Player_Info     player_info;                            // player information after actions
Bag_Info        bag_info;
PKM_Info        pkm_info;
logic           bracer_buff;

Player_Info     def_player_info;
Bag_Info        def_bag_info;
PKM_Info        def_pkm_info;

Money_expand    updated_money;
Item_num_expand updated_berry_num;
Item_num_expand updated_medicine_num;
Item_num_expand updated_candy_num;
Item_num_expand updated_bracer_num;
Stone           updated_stone;

Stage           updated_stage;
PKM_Type        updated_pkm_type;
HP_expand       updated_hp;
ATK             updated_atk;
EXP             updated_exp;

Stage           updated_def_stage;
HP_expand       updated_def_hp;
ATK             updated_def_atk;
EXP             updated_def_exp;

EXP             typical_exp;
Stage           typical_stage;
HP              typical_hp;
ATK             typical_atk;

logic           stone_evolve_cond;
logic           exp_evolve_cond;

logic money_overflow;                                   // error identification
logic berry_num_overflow;
logic medicine_num_overflow;
logic candy_num_overflow;
logic bracer_num_overflow;

// Meta Information
// Table 3: The price to buy or sell Pokemons.
// Table 9: Item that can be used to benefit Pokemon
// Category (category), PKM_Type (pkm_type), Item (item)                                    --> Money (buy_price)
// Category (category), PKM_Type (pkm_info.pkm_type), Stage(pkm_info.stage), Item (item)    --> Money (sell_price)
Money       buy_price;              
Money       sell_price;

// Table 4: The information of different type and different stage of Pokemons
// PKM_Type (pkm_info.pkm_type), Stage (pkm_info.stage) --> PKM_Stats ([HP, ATK, EXP])
PKM_Stats   pkm_stats;

// Used for initialization of buying pokemon
// PKM_Type (pkm_type) --> HP (initial_hp), ATK (initial_atk)
HP          initial_hp;
ATK         initial_atk;

// Used for initialization of stone-evolving
// Item (item) --> HP (stone_evolve_hp), ATK (stone_evolve_atk)
HP          stone_evolve_hp;
ATK         stone_evolve_atk;

// Used for initialization of exp-evolving
// PKM_Type (pkm_info.pkm_type), Stage (pkm_info.stage) --> HP (exp_evolve_hp), ATK (exp_evolve_atk)
HP          exp_evolve_hp;
ATK         exp_evolve_atk;

// Defender's information
// EXP evolving condition & HP, ATK initialization of exp-evolving
PKM_Stats   def_pkm_stats;

// Table 5: The corresponding value of actions and error messages.
// Error Identification
Error_Msg error_msg_comb;

logic err_oom;          // Out of money                     (Buy)
logic err_pkm_full;     // Already have a Pokemon           (Buy)
logic err_bag_full;     // Bag is full                      (Buy)
logic err_pkm_empty;    // Do not have a Pokemon            (Sell, Use_item, Attack)
logic err_bag_empty;    // Do not have a item               (Sell, Use_item)
logic err_pkm_low;      // Pokemon is in the lowest stage   (Sell)
logic err_ooh;          // HP is zero                       (Attack)

// Table 6: Pokemon type chart, the actual damage should multiply the number in the chart, round down to the integer
// Calculation of effective damage
// ATK (pkm_stats.atk), logic (bracer_buff) --> ATK (buffed_atk)
// PKM_Type (pkm_info.pkm_type), PKM_Type (def_pkm_info.pkm_type) --> ATK_expand (effective_dmg)
ATK         buffed_atk;
ATK_expand  effective_dmg;

// Table 7: The Exp reward after the "Attack"
// Stage (def_pkm_info.stage) --> EXP (attacker_exp)
// Stage (    pkm_info.stage) --> EXP (defender_exp)
EXP         attacker_exp;
EXP         defender_exp;

// Table 8: The code of evolutionary stone when storing in the bag
// Item (item) --> Stone (item_stone_map)
Stone       item_stone_map;

// Table 3: The price to buy or sell Pokemons.
// Table 9: Item that can be used to benefit Pokemon
// Category (category), PKM_Type (pkm_type), Item (item)                                    --> Money (buy_price)
// Category (category), PKM_Type (pkm_info.pkm_type), Stage(pkm_info.stage), Item (item)    --> Money (sell_price)
// Buy Price
always_comb begin
    if (category==Pkm) begin    // Pokemon
        case (pkm_type)
            Grass:      buy_price = 'd100;
            Fire:       buy_price = 'd 90;
            Water:      buy_price = 'd110;
            Electric:   buy_price = 'd120;
            Normal:     buy_price = 'd130;
            default:    buy_price = 'd  0;
        endcase
    end
    else begin                  // Item
        case (item)
            Berry:          buy_price = 'd 16;
            Medicine:       buy_price = 'd128;
            Candy:          buy_price = 'd300;
            Bracer:         buy_price = 'd 64; 
            Water_stone,
            Fire_stone,
            Thunder_stone:  buy_price = 'd800;	
            default:        buy_price = 'd  0;
        endcase
    end
end

// Sell Price
always_comb begin
    if (category==Pkm) begin    // Pokemon
        case ({pkm_info.pkm_type, pkm_info.stage})
            {Grass,     Middle}:    sell_price = 'd 510;
            {Grass,     Highest}:   sell_price = 'd1100;
            {Fire,      Middle}:    sell_price = 'd 450;
            {Fire,      Highest}:   sell_price = 'd1000;
            {Water,     Middle}:    sell_price = 'd 500;
            {Water,     Highest}:   sell_price = 'd1200;
            {Electric,  Middle}:    sell_price = 'd 550;
            {Electric,  Highest}:   sell_price = 'd1300;
            default:                sell_price = 'd   0;
        endcase
    end
    else begin                  // Item
        case (item)
            Berry:          sell_price = 'd 12;
            Medicine:       sell_price = 'd 96;
            Candy:          sell_price = 'd225;
            Bracer:         sell_price = 'd 48; 
            Water_stone,
            Fire_stone,
            Thunder_stone:  sell_price = 'd600;	
            default:        sell_price = 'd  0; 
        endcase
    end
end

// Table 4: The information of different type and different stage of Pokemons
// PKM_Type (pkm_info.pkm_type), Stage (pkm_info.stage) --> PKM_Stats ([HP, ATK, EXP])
// Pokemon Stats for each type & stage
always_comb begin
    case ({pkm_info.pkm_type, pkm_info.stage})
        {Grass,     Lowest}:    begin pkm_stats.hp = 'd128; pkm_stats.atk = 'd 63; pkm_stats.exp = 'd32; end
        {Grass,     Middle}:    begin pkm_stats.hp = 'd192; pkm_stats.atk = 'd 94; pkm_stats.exp = 'd63; end
        {Grass,     Highest}:   begin pkm_stats.hp = 'd254; pkm_stats.atk = 'd123; pkm_stats.exp = 'd 0; end

        {Fire,      Lowest}:    begin pkm_stats.hp = 'd119; pkm_stats.atk = 'd 64; pkm_stats.exp = 'd30; end
        {Fire,      Middle}:    begin pkm_stats.hp = 'd177; pkm_stats.atk = 'd 96; pkm_stats.exp = 'd59; end
        {Fire,      Highest}:   begin pkm_stats.hp = 'd225; pkm_stats.atk = 'd127; pkm_stats.exp = 'd 0; end
        
        {Water,     Lowest}:    begin pkm_stats.hp = 'd125; pkm_stats.atk = 'd 60; pkm_stats.exp = 'd28; end
        {Water,     Middle}:    begin pkm_stats.hp = 'd187; pkm_stats.atk = 'd 89; pkm_stats.exp = 'd55; end
        {Water,     Highest}:   begin pkm_stats.hp = 'd245; pkm_stats.atk = 'd113; pkm_stats.exp = 'd 0; end
        
        {Electric,  Lowest}:    begin pkm_stats.hp = 'd122; pkm_stats.atk = 'd 65; pkm_stats.exp = 'd26; end
        {Electric,  Middle}:    begin pkm_stats.hp = 'd182; pkm_stats.atk = 'd 97; pkm_stats.exp = 'd51; end
        {Electric,  Highest}:   begin pkm_stats.hp = 'd235; pkm_stats.atk = 'd124; pkm_stats.exp = 'd 0; end
        
        {Normal,    Lowest}:    begin pkm_stats.hp = 'd124; pkm_stats.atk = 'd 62; pkm_stats.exp = 'd29; end
        default:                begin pkm_stats.hp = 'd  0; pkm_stats.atk = 'd  0; pkm_stats.exp = 'd 0; end
    endcase
end

// resuorce sharing for initial_*, stone_evolve_* and exp_evolve_*
// Initial hp (used for initialize HP when buying Pokemon)
always_comb begin
    case (pkm_type)
        Grass:      initial_hp = 'd128;
        Fire:       initial_hp = 'd119;
        Water:      initial_hp = 'd125;
        Electric:   initial_hp = 'd122;
        Normal:     initial_hp = 'd124;
        default:    initial_hp = 'd  0;
    endcase
end

// Initial atk  (used for initialize ATK when buying Pokemon)
always_comb begin
    case (pkm_type)
        Grass:      initial_atk = 'd63;
        Fire:       initial_atk = 'd64;
        Water:      initial_atk = 'd60;
        Electric:   initial_atk = 'd65;
        Normal:     initial_atk = 'd62;
        default:    initial_atk = 'd 0;
    endcase
end

// Evolving hp (used for initialize HP when evolving from using stone)
always_comb begin
    case (item)
        Water_stone:    stone_evolve_hp = 'd245;
        Fire_stone:     stone_evolve_hp = 'd225;
        Thunder_stone:  stone_evolve_hp = 'd235;
        default:        stone_evolve_hp = 'd  0;
    endcase
end

// Evolving atk (used for initialize ATK when evolving from using stone)
always_comb begin
    case (item)
        Water_stone:    stone_evolve_atk = 'd113;
        Fire_stone:     stone_evolve_atk = 'd127;
        Thunder_stone:  stone_evolve_atk = 'd124;
        default:        stone_evolve_atk = 'd  0;
    endcase
end

// Evolving hp (used for initialize HP when evolving from getting experience)
always_comb begin
    case ({pkm_info.pkm_type, pkm_info.stage})
        {Grass,     Lowest}:    exp_evolve_hp = 'd192;
        {Grass,     Middle}:    exp_evolve_hp = 'd254;

        {Fire,      Lowest}:    exp_evolve_hp = 'd177;
        {Fire,      Middle}:    exp_evolve_hp = 'd225;
        
        {Water,     Lowest}:    exp_evolve_hp = 'd187;
        {Water,     Middle}:    exp_evolve_hp = 'd245;
        
        {Electric,  Lowest}:    exp_evolve_hp = 'd182;
        {Electric,  Middle}:    exp_evolve_hp = 'd235;
        default:                exp_evolve_hp = 'd  0;
    endcase
end

// Evolving atk (used for initialize ATK when evolving from getting experience)
always_comb begin
    case ({pkm_info.pkm_type, pkm_info.stage})
        {Grass,     Lowest}:    exp_evolve_atk = 'd 94;
        {Grass,     Middle}:    exp_evolve_atk = 'd123;

        {Fire,      Lowest}:    exp_evolve_atk = 'd 96;
        {Fire,      Middle}:    exp_evolve_atk = 'd127;
        
        {Water,     Lowest}:    exp_evolve_atk = 'd 89;
        {Water,     Middle}:    exp_evolve_atk = 'd113;
        
        {Electric,  Lowest}:    exp_evolve_atk = 'd 97;
        {Electric,  Middle}:    exp_evolve_atk = 'd124;
        default:                exp_evolve_atk = 'd  0;
    endcase
end

// Defending Pokemon Stats for each type & stage
// Evolving exp of defender (the upper bound of defender experience's upper bound)
// Evolving hp  of defender (used for initialize HP  when evolving from getting experience)
// Evolving atk of defebder (used for initialize ATK when evolving from getting experience)
always_comb begin
    case ({def_pkm_info.pkm_type, def_pkm_info.stage})
        {Grass,     Lowest}:    begin def_pkm_stats.hp = 'd192; def_pkm_stats.atk = 'd 94; def_pkm_stats.exp = 'd32; end
        {Grass,     Middle}:    begin def_pkm_stats.hp = 'd254; def_pkm_stats.atk = 'd123; def_pkm_stats.exp = 'd63; end    

        {Fire,      Lowest}:    begin def_pkm_stats.hp = 'd177; def_pkm_stats.atk = 'd 96; def_pkm_stats.exp = 'd30; end    
        {Fire,      Middle}:    begin def_pkm_stats.hp = 'd225; def_pkm_stats.atk = 'd127; def_pkm_stats.exp = 'd59; end    
        
        {Water,     Lowest}:    begin def_pkm_stats.hp = 'd187; def_pkm_stats.atk = 'd 89; def_pkm_stats.exp = 'd28; end    
        {Water,     Middle}:    begin def_pkm_stats.hp = 'd245; def_pkm_stats.atk = 'd113; def_pkm_stats.exp = 'd55; end    
        
        {Electric,  Lowest}:    begin def_pkm_stats.hp = 'd182; def_pkm_stats.atk = 'd 97; def_pkm_stats.exp = 'd26; end    
        {Electric,  Middle}:    begin def_pkm_stats.hp = 'd235; def_pkm_stats.atk = 'd124; def_pkm_stats.exp = 'd51; end    
        
        {Normal,    Lowest}:    begin def_pkm_stats.hp = 'd  0; def_pkm_stats.atk = 'd 0;  def_pkm_stats.exp = 'd29; end
        default:                begin def_pkm_stats.hp = 'd  0; def_pkm_stats.atk = 'd 0;  def_pkm_stats.exp = 'd 0; end
    endcase
end

// Table 5: The corresponding value of actions and error messages.
// Error Identification
// 1. Out of money
assign err_oom = money_overflow;

// 2. Already have a Pokemon
assign err_pkm_full = (pkm_info.pkm_type != No_type);

// 3. Bag is full
always_comb begin
    case (item)
        Berry:          err_bag_full = berry_num_overflow;
        Medicine:       err_bag_full = medicine_num_overflow;
        Candy:          err_bag_full = candy_num_overflow;
        Bracer:         err_bag_full = bracer_num_overflow; 
        Water_stone,
        Fire_stone,
        Thunder_stone:  err_bag_full = (bag_info.stone != No_stone);	 
        default:        err_bag_full = 0;
    endcase
end

// 4. Do not have a Pokemon
always_comb begin
    case (action)
        Sell,
        Use_item:   err_pkm_empty = (pkm_info.pkm_type == No_type);
        Attack:     err_pkm_empty = ((pkm_info.pkm_type == No_type) || (def_pkm_info.pkm_type == No_type));
        default:    err_pkm_empty = 0;
    endcase
end

// 5. Do not have item
// resouce sharing for error-3 and error-5
always_comb begin
    case (item)
        Berry:          err_bag_empty = berry_num_overflow;
        Medicine:       err_bag_empty = medicine_num_overflow;
        Candy:          err_bag_empty = candy_num_overflow;
        Bracer:         err_bag_empty = bracer_num_overflow;
        Water_stone:    err_bag_empty = (bag_info.stone != W_stone);
        Fire_stone:     err_bag_empty = (bag_info.stone != F_stone);
        Thunder_stone:  err_bag_empty = (bag_info.stone != T_stone);
        default:        err_bag_empty = 0;
    endcase
end

// 6. Pokemon is in the lowest stage
assign err_pkm_low = (pkm_info.stage == Lowest);

// 7. HP is zero
assign err_ooh = ((pkm_info.hp == 0) || (def_pkm_info.hp == 0));

// combinational circuit of error message
always_comb begin
    case (action)
        Buy: begin
            if (err_oom)                                    error_msg_comb = Out_of_money;      // 1
            else if (err_pkm_full && (category == Pkm))     error_msg_comb = Already_Have_PKM;  // 2
            else if (err_bag_full && (category == Itm))     error_msg_comb = Bag_is_full;       // 3
            else                                            error_msg_comb = No_Err;
        end
        Sell: begin
            if (err_pkm_empty && (category == Pkm))         error_msg_comb = Not_Having_PKM;    // 1
            else if (err_bag_empty && (category == Itm))    error_msg_comb = Not_Having_Item;   // 2
            else if (err_pkm_low && (category == Pkm))      error_msg_comb = Has_Not_Grown;     // 3
            else                                            error_msg_comb = No_Err;
        end        
        Use_item: begin
            if (err_pkm_empty)                              error_msg_comb = Not_Having_PKM;    // 1
            else if (err_bag_empty)                         error_msg_comb = Not_Having_Item;   // 2
            else                                            error_msg_comb = No_Err;
        end
        Attack: begin
            if (err_pkm_empty)                              error_msg_comb = Not_Having_PKM;    // 1
            else if (err_ooh)                               error_msg_comb = HP_is_Zero;        // 2
            else                                            error_msg_comb = No_Err;
        end
        default:                                            error_msg_comb = No_Err;
    endcase
end

// Table 6: Pokemon type chart, the actual damage should multiply the number in the chart, round down to the integer
// Calculation of effective damage
// ATK (pkm_stats.atk), logic (bracer_buff) --> ATK (buffed_atk)
// PKM_Type (pkm_info.pkm_type), PKM_Type (def_pkm_info.pkm_type) --> ATK_expand (effective_dmg)

// Range: (127 [Highest Fire Pokemon] + 32 [Bracer]) * 2 [Grass Defender] = 318
assign buffed_atk = pkm_stats.atk + (bracer_buff ? 32 : 0);

always_comb begin
    case ({pkm_info.pkm_type,def_pkm_info.pkm_type})
        {Grass,     Grass},
        {Grass,     Fire},
        {Fire,      Fire},
        {Fire,      Water},
        {Water,     Grass},
        {Water,     Water},
        {Electric,  Grass},
        {Electric,  Electric}:  effective_dmg = buffed_atk >> 1;

        {Grass,     Water},
        {Fire,      Grass},
        {Water,     Fire},
        {Electric,  Water}:     effective_dmg = buffed_atk << 1;

        // {Grass,     Electric}:
        // {Grass,     Normal}:
        // {Fire,      Electric}:
        // {Fire,      Normal}:
        // {Water,     Electric}:
        // {Water,     Normal}:
        // {Electric,  Fire}:
        // {Electric,  Normal}:
        // {Normal,    Grass}:
        // {Normal,    Fire}:
        // {Normal,    Water}:
        // {Normal,    Electric}:
        // {Normal,    Normal}:
        default:                effective_dmg = buffed_atk;
    endcase
end

// Table 7: The Exp reward after the "Attack"
// Stage (def_pkm_info.stage) --> EXP (attacker_exp)
// Stage (    pkm_info.stage) --> EXP (defender_exp)
always_comb begin
    case (def_pkm_info.stage)
        Lowest:     attacker_exp = 'd16;
        Middle:     attacker_exp = 'd24;
        Highest:    attacker_exp = 'd32;
        default:    attacker_exp = 'd 0; 
    endcase
end

always_comb begin
    case (pkm_info.stage)
        Lowest:     defender_exp = 'd 8;
        Middle:     defender_exp = 'd12;
        Highest:    defender_exp = 'd16;
        default:    defender_exp = 'd 0;   
    endcase
end

// Table 8: The code of evolutionary stone when storing in the bag
// Item (item) --> Stone (item_stone_map)
always_comb begin
    case (item)
        Water_stone:    item_stone_map = W_stone;
        Fire_stone:     item_stone_map = F_stone;
        Thunder_stone:  item_stone_map = T_stone;
        default:        item_stone_map = No_stone;
    endcase
end

// DEBUG
// always @(posedge clk) begin
//     $display($time);
//     $display("DEBUG %p", def_pkm_info);
// end

// ===============================================================
//                           Design
// ===============================================================
// Main FSM
// current state
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) current_state <= STATE_ID_ACT;
    else            current_state <= next_state;
end

// next state
always_comb begin
    case (current_state)
        STATE_ID_ACT: begin     // Idle, wait for player_id or action signals
            if (inf.act_valid) begin
                if (inf.D.d_act[0] == Check)    next_state = STATE_WAIT;
                else                            next_state = STATE_ACT_ARG;
            end
            else                                next_state = current_state;
        end
        STATE_ACT_ARG: begin    // Wait for action argument signals if needed
            if (
                (inf.type_valid) || 
                (inf.item_valid) || 
                (inf.amnt_valid) || 
                (inf.id_valid)
            )                                   next_state = STATE_WAIT;
            else                                next_state = current_state;
        end
        STATE_WAIT: begin       // Wait for getting all required player information
            if  (
                    (current_axi_state == AXI_WRITE) && // getting attacking player information
                    (finish_load_def)                   // getting defending player information
                )                               next_state = STATE_CALC;
            else                                next_state = current_state;
        end
        STATE_CALC:                             next_state = STATE_OUTPUT;
        STATE_OUTPUT:                           next_state = STATE_ID_ACT;
        default:                                next_state = current_state;
    endcase
end

//   ---------------------------------------------   
//   |                                           | 
//   ---> Write --> Wait --> Read --> Wait ----> |
//       (Idle)             (Init)

// AXI FSM
// current state
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) current_axi_state <= AXI_INIT;
    else            current_axi_state <= next_axi_state;
end

always_comb begin
    case (current_axi_state)
        AXI_INIT:   if (inf.id_valid)                       next_axi_state = AXI_RWAIT; else next_axi_state = current_axi_state;
        AXI_WRITE:  if (change_user && (!duplicate_player)) next_axi_state = AXI_WWAIT; else next_axi_state = current_axi_state;
        AXI_WWAIT:  if (inf.C_out_valid)                    next_axi_state = AXI_READ;  else next_axi_state = current_axi_state;
        AXI_READ:   next_axi_state = AXI_RWAIT;
        AXI_RWAIT:  if (inf.C_out_valid)                    next_axi_state = AXI_WRITE; else next_axi_state = current_axi_state;
        default:    next_axi_state = current_axi_state; // will not happen
    endcase
end

assign change_user =        ((current_state == STATE_ID_ACT) && (inf.id_valid));    // changing user before action
assign duplicate_player =   (def_player_id == inf.D.d_id[0]);                       // the main player is same as last defender (swap data)

// AXI Sub FSM
// current state
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) current_axi_substate <= AXI_INIT;
    else            current_axi_substate <= next_axi_substate;
end

// next state
always_comb begin
    // the condition to process defender information
    if (
        (current_state == STATE_WAIT)   && // Load attacker first
        (action == Attack)              && // If loading defender is needed
        (current_axi_state == AXI_WRITE)   // Finish loading attacker 
    ) begin
        case (current_axi_substate)
            AXI_INIT:   next_axi_substate = AXI_RWAIT;
            AXI_WRITE:  if (!finish_load_def)   next_axi_substate = AXI_WWAIT; else next_axi_substate = current_axi_substate;
            AXI_WWAIT:  if (inf.C_out_valid)    next_axi_substate = AXI_READ;  else next_axi_substate = current_axi_substate;
            AXI_READ:   next_axi_substate = AXI_RWAIT;
            AXI_RWAIT:  if (inf.C_out_valid)    next_axi_substate = AXI_WRITE; else next_axi_substate = current_axi_substate;
            default:    next_axi_substate = current_axi_substate;
        endcase
    end
    else                next_axi_substate = current_axi_substate;
end

// Signal identifying whether or not loading defender information is required
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)                                                     finish_load_def <= 1;
    else if ((current_state == STATE_ACT_ARG) && (inf.id_valid))        finish_load_def <= 0;
    else if ((current_axi_substate == AXI_RWAIT) && (inf.C_out_valid))  finish_load_def <= 1;
end

// output logic
// User (Pattern) Side
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)                         inf.out_valid <= 0;
    else if (current_state == STATE_OUTPUT) inf.out_valid <= 1;
    else                                    inf.out_valid <= 0;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)                         inf.complete <= 0;
    else if (current_state == STATE_CALC)   inf.complete <= (error_msg_comb == No_Err);
    else                                    inf.complete <= inf.complete;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)                         inf.err_msg <= No_Err;
    else if (current_state == STATE_CALC)   inf.err_msg <= error_msg_comb;
    else                                    inf.err_msg <= inf.err_msg;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)                 inf.out_info <= 0;
    else begin
        if (inf.err_msg == No_Err) begin
            if (action == Attack)   inf.out_info <= {player_info.pkm_info, def_player_info.pkm_info};
            else                    inf.out_info <= player_info + (bracer_buff << 13);  // player info w/o bracer buff + ATK( 0/32)
        end
        else                        inf.out_info <= 0;
    end
end

// AXI Side
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        inf.C_in_valid  <= 0;
        inf.C_addr      <= 0;
        inf.C_r_wb      <= 0;
        inf.C_data_w    <= 0;
    end
    else begin
        case (current_axi_state)
            AXI_INIT: begin
                if (inf.id_valid) begin                                         // read attacker
                    inf.C_in_valid  <= 1;
                    inf.C_addr      <= inf.D.d_id[0];
                    inf.C_r_wb      <= 1;                                       // read
                end
                else begin
                    inf.C_in_valid  <= 0;
                end
            end
            AXI_WRITE: begin
                if (change_user && (!duplicate_player)) begin                   // write attacker
                    inf.C_in_valid  <= 1;
                    inf.C_addr      <= player_id;
                    inf.C_r_wb      <= 0;                                       // write
                    {
                        inf.C_data_w[ 7: 0],
                        inf.C_data_w[15: 8],
                        inf.C_data_w[23:16],
                        inf.C_data_w[31:24],
                        inf.C_data_w[39:32],
                        inf.C_data_w[47:40],
                        inf.C_data_w[55:48],
                        inf.C_data_w[63:56]
                    } <= player_info;
                end
                else if (!finish_load_def) begin
                    case (current_axi_substate)
                        AXI_INIT,
                        AXI_READ: begin                                         // read defender
                            inf.C_in_valid  <= 1;
                            inf.C_addr      <= last_player_id;
                            inf.C_r_wb      <= 1;                               // read
                        end
                        AXI_WRITE: begin                                        // write defender
                            inf.C_in_valid  <= 1;
                            inf.C_addr      <= def_player_id;
                            inf.C_r_wb      <= 0;                               // write
                            {
                                inf.C_data_w[ 7: 0],
                                inf.C_data_w[15: 8],
                                inf.C_data_w[23:16],
                                inf.C_data_w[31:24],
                                inf.C_data_w[39:32],
                                inf.C_data_w[47:40],
                                inf.C_data_w[55:48],
                                inf.C_data_w[63:56]
                            } <= def_player_info;
                        end
                        default: begin
                            inf.C_in_valid  <= 0;
                        end
                    endcase
                end
                else begin
                    inf.C_in_valid  <= 0;
                end
            end
            AXI_READ: begin                                                     // read attacker
                inf.C_in_valid  <= 1;
                inf.C_addr      <= player_id;
                inf.C_r_wb      <= 1;                                           // read
            end
            default: begin
                inf.C_in_valid  <= 0;
            end
        endcase
    end
end

// Input Signals
// User (Pattern) Side
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)                                                     player_id <= -1;
    else if ((inf.id_valid) && (current_state==STATE_ID_ACT))           player_id <= inf.D.d_id[0];
    else                                                                player_id <= player_id;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)                                                     def_player_id <= -1;
    else if (change_user && duplicate_player)                           def_player_id <= player_id;
    else if ((current_axi_substate == AXI_RWAIT) && (inf.C_out_valid))  def_player_id <= last_player_id; // update when finish reading
    else                                                                def_player_id <= def_player_id;
end

// buffer signals used for defending player
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)         last_player_id <= 0;
    else if (inf.id_valid)  last_player_id <= inf.D.d_id[0];
    else                    last_player_id <= last_player_id;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
   if (!inf.rst_n)              action <= No_action;
   else if (inf.act_valid)      action <= inf.D.d_act[0];
   else                         action <= action;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             category <= Pkm; // Reset to zero
    else if (inf.type_valid)    category <= Pkm;
    else if (inf.item_valid)    category <= Itm;
    else                        category <= category;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             pkm_type <= No_type;
    else if (inf.type_valid)    pkm_type <= inf.D.d_type[0];
    else if (inf.item_valid)    pkm_type <= No_type;
    else                        pkm_type <= pkm_type;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             item <= No_item;
    else if (inf.item_valid)    item <= inf.D.d_item[0];
    else if (inf.type_valid)    item <= No_item;
    else                        item <= item;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)             deposit_money <= 0;
    else if (inf.amnt_valid)    deposit_money <= inf.D.d_money;
    else                        deposit_money <= deposit_money;
end

// AXI Side
assign player_info.bag_info = bag_info;
assign player_info.pkm_info = pkm_info;

assign def_player_info.bag_info = def_bag_info;
assign def_player_info.pkm_info = def_pkm_info;

// Action Calculation
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
                        bag_info.berry_num      <= 0;
                        bag_info.medicine_num   <= 0;
                        bag_info.candy_num      <= 0;
                        bag_info.bracer_num     <= 0;
                        bag_info.stone          <= No_stone;
                        bag_info.money          <= 0;

                        pkm_info.stage          <= No_stage;
                        pkm_info.pkm_type       <= No_type;
                        pkm_info.hp             <= 0;
                        pkm_info.atk            <= 0;
                        pkm_info.exp            <= 0;
    end
    else begin 
        case (current_axi_state)
            AXI_RWAIT: begin
                if (inf.C_out_valid) begin                          // loading player information from AXI / DRAM
                    bag_info <= {
                        inf.C_data_r[ 7: 0],
                        inf.C_data_r[15: 8],
                        inf.C_data_r[23:16],
                        inf.C_data_r[31:24]
                    };
                    pkm_info <= {
                        inf.C_data_r[39:32],
                        inf.C_data_r[47:40],
                        inf.C_data_r[55:48],
                        inf.C_data_r[63:56]
                    };
                    bracer_buff <= 0;                               // changing user
                end
                else begin
                    bag_info <= bag_info;
                    pkm_info <= pkm_info;
                    bracer_buff <= bracer_buff;
                end
            end
            AXI_WRITE: begin
                if (change_user && duplicate_player) begin          // swap two player information
                    bag_info                <= def_bag_info;
                    pkm_info                <= def_pkm_info;
                    bracer_buff             <= 0;                   // changing user
                end
                else if (
                    (current_state == STATE_CALC)       &&          // finish loading attacker
                    (finish_load_def)                   &&          // finish loading defender
                    (error_msg_comb == No_Err)                      // no error
                ) begin
                    bag_info.berry_num      <= updated_berry_num;
                    bag_info.medicine_num   <= updated_medicine_num;
                    bag_info.candy_num      <= updated_candy_num;
                    bag_info.bracer_num     <= updated_bracer_num;
                    bag_info.stone          <= updated_stone;
                    bag_info.money          <= updated_money;

                    pkm_info.stage          <= updated_stage;
                    pkm_info.pkm_type       <= updated_pkm_type;
                    pkm_info.hp             <= updated_hp;
                    pkm_info.atk            <= updated_atk;
                    pkm_info.exp            <= updated_exp;

                    if ((action == Use_item) && (item == Bracer))   bracer_buff <= 1;
                    else if (
                        (stone_evolve_cond)                     ||  // evolving
                        (exp_evolve_cond)                       ||  // evolving
                        ((action == Sell) && (category == Pkm)) ||  // selling Pokemon
                        (action == Attack)                          // performing attacking
                    )                                               bracer_buff <= 0;
                    else                                            bracer_buff <= bracer_buff;
                end
                else begin
                    bag_info                <= bag_info;
                    pkm_info                <= pkm_info;
                    bracer_buff             <= bracer_buff;
                end
            end
            default: begin
                    bag_info                <= bag_info;
                    pkm_info                <= pkm_info;
                    bracer_buff             <= bracer_buff;
            end
        endcase
    end
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    // $display("DEBUG %p",def_pkm_info);
    if (!inf.rst_n) begin
        def_bag_info.berry_num      <= 0;
        def_bag_info.medicine_num   <= 0;
        def_bag_info.candy_num      <= 0;
        def_bag_info.bracer_num     <= 0;
        def_bag_info.stone          <= No_stone;
        def_bag_info.money          <= 0;

        def_pkm_info.stage          <= No_stage;
        def_pkm_info.pkm_type       <= No_type;
        def_pkm_info.hp             <= 0;
        def_pkm_info.atk            <= 0;
        def_pkm_info.exp            <= 0;
    end
    else if (current_axi_state == AXI_WRITE) begin
        case (current_axi_substate)
            AXI_RWAIT: begin
                if (inf.C_out_valid) begin                          // loading player information from AXI / DRAM                        
                    def_bag_info <= {
                        inf.C_data_r[ 7: 0],
                        inf.C_data_r[15: 8],
                        inf.C_data_r[23:16],
                        inf.C_data_r[31:24]
                    };
                    def_pkm_info <= {
                        inf.C_data_r[39:32],
                        inf.C_data_r[47:40],
                        inf.C_data_r[55:48],
                        inf.C_data_r[63:56]
                    };
                end
                else begin                                          
                    def_bag_info <= def_bag_info;
                    def_pkm_info <= def_pkm_info;
                end
            end
            AXI_WRITE: begin
                if (change_user && duplicate_player) begin          // swap two player information
                    def_bag_info            <= bag_info;
                    def_pkm_info            <= pkm_info;
                end
                else if (
                    (current_state == STATE_CALC) &&                // finish loading attacker
                    (finish_load_def) &&                            // finish loading defender
                    (error_msg_comb == No_Err)                      // no error
                ) begin
                    def_bag_info                <= def_bag_info;

                    def_pkm_info.stage          <= updated_def_stage;
                    def_pkm_info.pkm_type       <= def_pkm_info.pkm_type;
                    def_pkm_info.hp             <= updated_def_hp;
                    def_pkm_info.atk            <= updated_def_atk;
                    def_pkm_info.exp            <= updated_def_exp;
                end
                else begin
                    def_bag_info                <= def_bag_info;
                    def_pkm_info                <= def_pkm_info;
                end
            end
            default: begin
                    def_bag_info                <= def_bag_info;
                    def_pkm_info                <= def_pkm_info;
            end
        endcase
    end
    else begin
                    def_bag_info                <= def_bag_info;
                    def_pkm_info                <= def_pkm_info;
    end
end

// Buy / Sell & Use_item / Others
// potential resource sharing
always_comb begin
    case (action)
        Buy,
        Sell,
        Use_item: begin
            updated_berry_num =      bag_info.berry_num +    (((category == Itm) && (item == Berry)) ?       ((action == Buy) ? 'd1 : -'d1) : 'd0);
            updated_medicine_num =   bag_info.medicine_num + (((category == Itm) && (item == Medicine)) ?    ((action == Buy) ? 'd1 : -'d1) : 'd0);
            updated_candy_num =      bag_info.candy_num +    (((category == Itm) && (item == Candy)) ?       ((action == Buy) ? 'd1 : -'d1) : 'd0);
            updated_bracer_num =     bag_info.bracer_num +   (((category == Itm) && (item == Bracer)) ?      ((action == Buy) ? 'd1 : -'d1) : 'd0);
        end
        default: begin
            updated_berry_num =      bag_info.berry_num;
            updated_medicine_num =   bag_info.medicine_num;
            updated_candy_num =      bag_info.candy_num;
            updated_bracer_num =     bag_info.bracer_num;
        end
    endcase
end

always_comb begin
    case ({item, action})
        {Water_stone,   Buy},
        {Fire_stone,    Buy},
        {Thunder_stone, Buy}:       updated_stone = (category == Itm) ? item_stone_map : bag_info.stone;
        {Water_stone,   Sell},
        {Fire_stone,    Sell},
        {Thunder_stone, Sell},
        {Water_stone,   Use_item},
        {Fire_stone,    Use_item},
        {Thunder_stone, Use_item}:  updated_stone = (category == Itm) ? No_stone : bag_info.stone;
        default:                    updated_stone = bag_info.stone;
    endcase
end

always_comb begin
    case (action)
        Buy:        updated_money = bag_info.money - buy_price;                                     // Buy
        Sell,
        Deposit: begin
                    updated_money = bag_info.money + ((action == Sell) ? sell_price : deposit_money); // Sell or Deposit
                    // the pattern should ensure player's money will not exceed limit
                    // updated_money = (money_overflow) ? 14'h3fff : updated_money;
        end    
        default:    updated_money = bag_info.money;
    endcase
end

assign money_overflow =         updated_money       [14];
assign berry_num_overflow =     updated_berry_num   [ 4];
assign medicine_num_overflow =  updated_medicine_num[ 4];
assign candy_num_overflow =     updated_candy_num   [ 4];
assign bracer_num_overflow =    updated_bracer_num  [ 4];

always_comb begin
    case (action)
        Buy:        if (category == Pkm)    updated_stage = Lowest;    else updated_stage = pkm_info.stage;
        Sell:       if (category == Pkm)    updated_stage = No_stage;  else updated_stage = pkm_info.stage;
        Use_item: begin
            case (item)
                Candy:          updated_stage = typical_stage;
                Water_stone,
                Fire_stone,
                Thunder_stone:  if (stone_evolve_cond) updated_stage = Highest; else updated_stage = pkm_info.stage;
                default:        updated_stage = pkm_info.stage;
            endcase
        end
        Attack:     updated_stage = typical_stage;
        default:    updated_stage = pkm_info.stage;
    endcase
end

always_comb begin
    case (action)
        Buy:                    if (category == Pkm) updated_pkm_type = pkm_type;   else updated_pkm_type = pkm_info.pkm_type; 
        Sell:                   if (category == Pkm) updated_pkm_type = No_type;    else updated_pkm_type = pkm_info.pkm_type;
        Use_item: begin
            case (item)
                Water_stone:    if (stone_evolve_cond) updated_pkm_type = Water;    else updated_pkm_type = pkm_info.pkm_type;
                Fire_stone:     if (stone_evolve_cond) updated_pkm_type = Fire;     else updated_pkm_type = pkm_info.pkm_type;
                Thunder_stone:  if (stone_evolve_cond) updated_pkm_type = Electric; else updated_pkm_type = pkm_info.pkm_type;
                default:        updated_pkm_type = pkm_info.pkm_type;
            endcase
        end
        default:                updated_pkm_type = pkm_info.pkm_type;
    endcase    
end

always_comb begin
    case (action)
        Buy:                    if (category == Pkm) updated_hp = initial_hp;   else updated_hp = pkm_info.hp;
        Sell:                   if (category == Pkm) updated_hp = 0;            else updated_hp = pkm_info.hp;
        Use_item: begin
            case (item)
                Berry: begin
                                updated_hp = pkm_info.hp + 32;
                                updated_hp = (updated_hp < pkm_stats.hp) ? updated_hp : pkm_stats.hp;
                end
                Medicine:       updated_hp = pkm_stats.hp;
                Candy:          updated_hp = typical_hp;
                Water_stone,  
                Fire_stone,   
                Thunder_stone:  if (stone_evolve_cond) updated_hp = stone_evolve_hp;  else updated_hp = pkm_info.hp;
                default:        updated_hp = pkm_info.hp;
            endcase
        end
        Attack:                 updated_hp = typical_hp;
        default:                updated_hp = pkm_info.hp;
    endcase
end

// ATK should be directly determined bt stage and type in case that DRAM information is wrong (includes bracer buff adjustment)
// pkm_info.atk --> pkm_stats.atk
always_comb begin
    case (action)   // the original attack without buff
        Buy:        if (category == Pkm)    updated_atk = initial_atk;  else updated_atk = pkm_stats.atk;
        Sell:       if (category == Pkm)    updated_atk = 0;            else updated_atk = pkm_stats.atk;
        Use_item: begin
            case (item)
                Candy:          updated_atk = typical_atk;
                Water_stone,
                Fire_stone,
                Thunder_stone:  if (stone_evolve_cond) updated_atk = stone_evolve_atk;  else updated_atk = pkm_stats.atk;
                default:        updated_atk = pkm_stats.atk;
            endcase
        end
        Attack:     updated_atk = typical_atk;
        default:    updated_atk = pkm_stats.atk;
    endcase
end

always_comb begin
    case (action)
        Buy,
        Sell:       if (category == Pkm)    updated_exp = 0;    else updated_exp = pkm_info.exp;
        Use_item: begin
            case (item)
                Candy:          updated_exp = typical_exp;
                Water_stone,
                Fire_stone,
                Thunder_stone:  if (stone_evolve_cond)  updated_exp = 0;            else updated_exp = pkm_info.exp;
                default:        updated_exp = pkm_info.exp;
            endcase
        end
        Attack:     updated_exp = typical_exp;
        default:    updated_exp = pkm_info.exp;
    endcase
end

// condition of evolution using stone
always_comb begin
    case (item)
        Water_stone,
        Fire_stone,
        Thunder_stone:  stone_evolve_cond = (
                                                (action == Use_item) && 
                                                (pkm_info.pkm_type == Normal) && 
                                                (pkm_info.exp == pkm_stats.exp)
                                            );
        default:        stone_evolve_cond = 0;
    endcase
end

// Typical Result Calculation determined by Exp update (using candy or attacking)
always_comb begin
    // Ignore EXP limit & overflow issue
    typical_exp =       pkm_info.exp + ((action == Attack) ? attacker_exp : ((action == Use_item) && (item == Candy)) ? 15 : 0);
    typical_stage =     pkm_info.stage;
    exp_evolve_cond =   0;
    typical_hp =        pkm_info.hp;
    typical_atk =       pkm_info.atk;
    // Consider EXP limit & overflow issue
    case ({pkm_info.pkm_type, pkm_info.stage})
        {Grass,     Lowest},
        {Grass,     Middle},
        {Fire,      Lowest},
        {Fire,      Middle},
        {Water,     Lowest},
        {Water,     Middle},
        {Electric,  Lowest},
        {Electric,  Middle}: begin // upgradable
            if (typical_exp >= pkm_stats.exp) begin // satisfy the upgrade condition
                typical_exp =       0;
                typical_stage =     (pkm_info.stage == Lowest) ? Middle : Highest;
                exp_evolve_cond =   1;
                typical_hp =        exp_evolve_hp;
                typical_atk =       exp_evolve_atk;
            end
            else begin
                typical_exp =       typical_exp;
                typical_stage =     typical_stage;
                exp_evolve_cond =   0;
                typical_hp =        typical_hp;
                typical_atk =       typical_atk;
            end
        end

        {Grass,     Highest},
        {Fire,      Highest},
        {Water,     Highest},
        {Electric,  Highest},
        {Normal,    Lowest}: begin // not upgradable
            typical_exp =       (typical_exp < pkm_stats.exp) ? typical_exp : pkm_stats.exp;
            typical_stage =     typical_stage;
            exp_evolve_cond =   0;
            typical_hp =        typical_hp;
            typical_atk =       typical_atk;
        end
        default: begin
            typical_exp =       typical_exp;
            typical_stage =     typical_stage;
            exp_evolve_cond =   0;
            typical_hp =        typical_hp;
            typical_atk =       typical_atk;
        end
    endcase
end

always_comb begin
    updated_def_stage = def_pkm_info.stage;
    updated_def_hp =    def_pkm_info.hp;
    updated_def_atk =   def_pkm_info.atk;
    updated_def_exp =   def_pkm_info.exp;
    if (action == Attack) begin
        // Update the attacking result
        updated_def_stage = updated_def_stage;
        updated_def_hp =    updated_def_hp - effective_dmg;             // Ignore   HP limit & overflow issue
        updated_def_hp =    (updated_def_hp[9]) ? 0 : updated_def_hp;   // Consider HP limit & overflow issue
        updated_def_atk =   updated_def_atk;
        updated_def_exp =   updated_def_exp + defender_exp;             // Ignore   EXP limit & overflow issue
        
        // Update the evolving result
        // Consider EXP limit & overflow issue
        case ({def_pkm_info.pkm_type, def_pkm_info.stage})
            {Grass,     Lowest},
            {Grass,     Middle},
            {Fire,      Lowest},
            {Fire,      Middle},
            {Water,     Lowest},
            {Water,     Middle},
            {Electric,  Lowest},
            {Electric,  Middle}: begin // upgradable
                if (updated_def_exp >= def_pkm_stats.exp) begin // satisfy the upgrade condition
                    updated_def_stage = (def_pkm_info.stage == Lowest) ? Middle : Highest;
                    updated_def_hp =    def_pkm_stats.hp;
                    updated_def_atk =   def_pkm_stats.atk;
                    updated_def_exp =   0;
                end
                else begin
                    updated_def_stage = updated_def_stage;
                    updated_def_hp =    updated_def_hp;
                    updated_def_atk =   updated_def_atk;
                    updated_def_exp =   updated_def_exp;
                end
            end

            {Grass,     Highest},
            {Fire,      Highest},
            {Water,     Highest},
            {Electric,  Highest},
            {Normal,    Lowest}: begin // not upgradable
                updated_def_stage = updated_def_stage;
                updated_def_hp =    updated_def_hp;
                updated_def_atk =   updated_def_atk;
                updated_def_exp =   (updated_def_exp < def_pkm_stats.exp) ? updated_def_exp : def_pkm_stats.exp;
            end
            default: begin
                updated_def_stage = updated_def_stage;
                updated_def_hp =    updated_def_hp;
                updated_def_atk =   updated_def_atk;
                updated_def_exp =   updated_def_exp;
            end
        endcase
    end
    else begin
        updated_def_stage = updated_def_stage;
        updated_def_hp =    updated_def_hp;
        updated_def_atk =   updated_def_atk;
        updated_def_exp =   updated_def_exp;
    end
end

endmodule