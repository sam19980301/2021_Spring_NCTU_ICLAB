`include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype_PKG.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
// Class Declaration
//================================================================
class Rand_Player;
    randc Player_id player_id;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint range {
        player_id inside {
            [0:255]
        };
    }
endclass

class Rand_Changeuser;
    rand int change_prob;
    logic changeuser;

    function new(int seed);
        this.srandom(seed);
        this.changeuser = 1;
    endfunction

    constraint range {
        (changeuser == 0) -> change_prob inside { [0:changeuser] };
        (changeuser == 1) -> change_prob inside { [0:1024] };
    }

    function void post_randomize();
        this.changeuser = (change_prob == 0);
    endfunction

endclass

class Rand_Action;
    rand Action action;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint range {
        action inside {
            Buy,
            Sell,
            Deposit,
            Use_item,
            Check,
            Attack
        };
    }
endclass

class Rand_Category;
    rand Category category;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint range {
        category inside {
            Pkm,
            Itm
        };
    }
endclass

class Rand_Pokemon_Type;
    rand PKM_Type pkm_type;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint range {
        pkm_type inside {
            Grass,
            Fire,
            Water,
            Electric,
            Normal
        };
    }
endclass

class Rand_Item;
    rand Item item;

    function new(int seed);
        this.srandom(seed);    
    endfunction

    constraint range {
        item inside {
            Berry,
            Medicine,
            Candy,
            Bracer,
            Water_stone,
            Fire_stone,
            Thunder_stone
        };
    }
endclass

class Rand_Money;
    rand Money money;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint range {
        // limited range to avoid overflow
        money inside {[1:128]};
    }
endclass

class Rand_Defender;
    rand Player_id player_id;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint range {
        player_id inside {
            [0:255]
        };
    }
endclass

// ===============================================================
// Parameter & Integer Declaration
// ===============================================================
// Meta Variable
parameter   DRAM_p_r =      "../00_TESTBED/DRAM/dram.dat";
parameter   TOTAL_PLAYER =  256;
parameter   TOTAL_PATTERN = 50000; // 775

parameter   DEBUG_MODE =    0;
parameter   seed =          0;

integer     i;
integer     calc_cycle, total_calc_cycle;
integer     pat;
integer     gap;


// Pattern Variable
Rand_Player         rand_player;
Rand_Changeuser     rand_changeuser;
Rand_Action         rand_action;
Rand_Category       rand_category;
Rand_Pokemon_Type   rand_pokemon_type;
Rand_Item           rand_item;
Rand_Money          rand_money;
Rand_Defender       rand_defender;

//================================================================
// Logic Declaration
//================================================================
logic [7:0]         golden_DRAM[((65536+256*8)-1):(65536+0)];

Player_id           player;
Action              action;
Category            category;
PKM_Type            pkm_type;
Item                item;
int                 money;
Player_id           def_player;

Player_Info         player_info;
Player_Info         def_player_info;
logic               bracer_buff;

Error_Msg           golden_err;
logic [63:0]        golden_output;

int                 updated_hp;
int                 effective_dmg;

// P.S. Clock and DRAM have been declared in TESTBED.v

//================================================================
// Initial
//================================================================

logic [2:0] test;
logic [1:0] val;

initial begin
    // Load DRAM Information
    $readmemh(DRAM_p_r, golden_DRAM);

    // player id
    rand_player =       new(seed);
    // change player
    rand_changeuser =   new(seed);
    // action
    rand_action =       new(seed);
    // buy, sell, use_item argument
    rand_category =     new(seed);
    rand_pokemon_type = new(seed);
    rand_item =         new(seed);
    // deposit argument
    rand_money =        new(seed);
    // attack argument
    rand_defender =     new(seed);
    
    
    // Reset Signal
    reset_signal;

    // Start Iterate Single Action
    total_calc_cycle = 0;
    for (pat=0; pat<TOTAL_PATTERN; pat=pat+1) begin
        input_signals;
        compute_answer;
        check_output;
        $display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32m Cycles: %3d\033[m", pat ,calc_cycle);
    end

    YOU_PASS_task;
end

// Pattern Rules
// SPEC 0.12                        (Done)
// SPEC 0.19                        (Done)
// SPEC 0.20                        (Done)
// SPEC 0.26                        (Done)

// The Design SPEC is checked in Lab09 CHECKER.sv
// SPEC  1 / ASSERTION 1          
// SPEC  8
// SPEC 12 / ASSERTION 5
// SPEC 13
// SPEC 14 / ASSERTION 6
// SPEC 15
// SPEC 17 / ASSERTION 2
// SPEC 18 / ASSERTION 3
// SPEC 19 / ASSERTION 7
// ASSERTION 4
// DESIGN CONSTRAINT / ASSERTION 8
// WRONG ANSWER

//================================================================
// Task
//================================================================

function Money PKM_PRICE(
    input Action    action,
    input Stage     stage,
    input PKM_Type  pkm_type
);
    if (action == Buy) begin
        case ({stage,pkm_type})
            {Lowest,    Grass}:     return 'd 100;
            {Lowest,    Fire}:      return 'd  90;
            {Lowest,    Water}:     return 'd 110;
            {Lowest,    Electric}:  return 'd 120;
            {Lowest,    Normal}:    return 'd 130;
            default:                return 'd   0;
        endcase
    end
    else begin
       case ({stage,pkm_type})
           {Middle,     Grass}:     return 'd 510;
           {Middle,     Fire}:      return 'd 450;
           {Middle,     Water}:     return 'd 500;
           {Middle,     Electric}:  return 'd 550;

           {Highest,    Grass}:     return 'd1100;
           {Highest,    Fire}:      return 'd1000;
           {Highest,    Water}:     return 'd1200;
           {Highest,    Electric}:  return 'd1300;
           default:                 return 'd   0;
       endcase 
    end
endfunction

function Money ITM_PRICE(
    input Action action,
    input Item   item
);
    case ({action, item})
        {Buy,   Berry}:         return 'd 16; 
        {Buy,   Medicine}:      return 'd128;
        {Buy,   Candy}:         return 'd300;
        {Buy,   Bracer}:        return 'd 64;
        {Buy,   Water_stone}:   return 'd800;
        {Buy,   Fire_stone}:    return 'd800;
        {Buy,   Thunder_stone}: return 'd800;

        {Sell,  Berry}:         return 'd 12;
        {Sell,  Medicine}:      return 'd 96;
        {Sell,  Candy}:         return 'd225;
        {Sell,  Bracer}:        return 'd 48;
        {Sell,  Water_stone}:   return 'd600;
        {Sell,  Fire_stone}:    return 'd600;
        {Sell,  Thunder_stone}: return 'd600;

        default:                return 'd  0;
    endcase    
endfunction

function HP PKM_HP(
    input Stage     stage,
    input PKM_Type  pkm_type
);
    case ({stage,pkm_type})
        {Lowest,    Grass}:     return 'd128;
        {Lowest,    Fire}:      return 'd119;
        {Lowest,    Water}:     return 'd125;
        {Lowest,    Electric}:  return 'd122;
        {Lowest,    Normal}:    return 'd124;

        {Middle,    Grass}:     return 'd192;
        {Middle,    Fire}:      return 'd177;
        {Middle,    Water}:     return 'd187;
        {Middle,    Electric}:  return 'd182;

        {Highest,   Grass}:     return 'd254;
        {Highest,   Fire}:      return 'd225;
        {Highest,   Water}:     return 'd245;
        {Highest,   Electric}:  return 'd235;

        default:                return 'd  0;
    endcase    
endfunction

function ATK PKM_ATK(
    input Stage     stage,
    input PKM_Type  pkm_type
);
    case ({stage,pkm_type})
        {Lowest,    Grass}:     return 'd 63;
        {Lowest,    Fire}:      return 'd 64;
        {Lowest,    Water}:     return 'd 60;
        {Lowest,    Electric}:  return 'd 65;
        {Lowest,    Normal}:    return 'd 62;

        {Middle,    Grass}:     return 'd 94;
        {Middle,    Fire}:      return 'd 96;
        {Middle,    Water}:     return 'd 89;
        {Middle,    Electric}:  return 'd 97;

        {Highest,   Grass}:     return 'd123;
        {Highest,   Fire}:      return 'd127;
        {Highest,   Water}:     return 'd113;
        {Highest,   Electric}:  return 'd124;

        default:                return 'd  0;
    endcase    
endfunction

function EXP PKM_EXP(
    input Stage     stage,
    input PKM_Type  pkm_type
);
    case ({stage,pkm_type})
        {Lowest,    Grass}:     return 'd32;
        {Lowest,    Fire}:      return 'd30;
        {Lowest,    Water}:     return 'd28;
        {Lowest,    Electric}:  return 'd26;
        {Lowest,    Normal}:    return 'd29;

        {Middle,    Grass}:     return 'd63;
        {Middle,    Fire}:      return 'd59;
        {Middle,    Water}:     return 'd55;
        {Middle,    Electric}:  return 'd51;

        default:                return 'd  0;
    endcase    
endfunction

function EXP ATK_EXP(
    input Stage def_stage
);
    case (def_stage)
        Lowest:     return 'd16;
        Middle:     return 'd24;
        Highest:    return 'd32;
        default:    return 'd 0;
    endcase    
endfunction

function EXP DEF_EXP(
    input Stage atk_stage
);
    case (atk_stage)
        Lowest:     return 'd 8;
        Middle:     return 'd12;
        Highest:    return 'd16;
        default:    return 'd 0;
    endcase    
endfunction

task reset_signal; begin
    #(1);
    inf.rst_n =         'b1;
    inf.D =             'bx;
    inf.id_valid =      'b0;
    inf.act_valid =     'b0;
    inf.item_valid =    'b0;
    inf.type_valid =    'b0;
    inf.amnt_valid =    'b0;
    
    #(2) inf.rst_n =    'b0;
    #(2) inf.rst_n =    'b1;

    // @(negedge clk);
end endtask

task input_signals; begin
    // (Player) --> Action --> (Argument)
    if (rand_changeuser.changeuser) begin   // changing player

        // bracer effect disappears after changing user (4/4)
        bracer_buff = 0;

        // random gap before player
        gap = $urandom_range(2,10);
        repeat(gap) @(negedge clk);

        // random player
        assert(rand_player.randomize());
        // SPEC 0.20 When changing the player, the new player ID won’t be the same as the previous one.
        assert (player != rand_player.player_id);
        player = rand_player.player_id;

        // specify signals
        inf.id_valid =  'b1;
        inf.D =         player;        
        @(negedge clk);
        inf.id_valid =  'b0;
        inf.D =         'bx;

        // random gap before action
        gap = $urandom_range(1,5); // 6
        repeat(gap) @(negedge clk);
    end
    else begin
        // random gap before action
        gap = $urandom_range(2,10);
        repeat(gap) @(negedge clk);
    end

    // specify rand_changeuser.changeuser for next action
    assert(rand_changeuser.randomize());

    // SPEC 0.19 Each player will perform at least one action before changing player.
    // random action
    assert(rand_action.randomize());
    action = rand_action.action;

    // specify signals
    inf.act_valid = 'b1;
    inf.D =         action;
    @(negedge clk);
    inf.act_valid = 'b0;
    inf.D =         'bx;
    
    if (action == Buy) begin            // argument: pkm_type or item
        // random choice of pkm_type or item
        assert(rand_category.randomize());
        assert(rand_pokemon_type.randomize());
        assert(rand_item.randomize());
        category = rand_category.category;
        pkm_type = rand_pokemon_type.pkm_type;
        item = rand_item.item;

        // random gap before argument
        gap = $urandom_range(1,5);
        repeat(gap) @(negedge clk);

        // specify signals
        inf.type_valid =    (category == Pkm);
        inf.item_valid =    (category == Itm);  // (category == Pkm)
        inf.D =             (category == Pkm) ? pkm_type : item;
        @(negedge clk);
        inf.type_valid =    'b0;
        inf.item_valid =    'b0;
        inf.D =             'bx;
    end
    else if (action == Sell) begin      // argument: pkm_type or item
        // random choice of pkm_type or item
        assert(rand_category.randomize());
        assert(rand_item.randomize());
        category = rand_category.category;        
        item = rand_item.item;

        // random gap before argument
        gap = $urandom_range(1,5);
        repeat(gap) @(negedge clk);

        // specify signals
        inf.type_valid =    (category == Pkm);
        inf.item_valid =    (category == Itm);
        inf.D =             (category == Pkm) ? 0 : item;
        @(negedge clk);
        inf.type_valid =    'b0;
        inf.item_valid =    'b0;
        inf.D =             'bx;
    end
    else if (action == Deposit) begin   // argument: amount of money
        // random amount of money
        assert(rand_money.randomize());
        money = rand_money.money;

        // random gap before argument
        gap = $urandom_range(1,5);
        repeat(gap) @(negedge clk);

        // specify signals
        inf.amnt_valid =    'b1;
        inf.D.d_money =     money;
        @(negedge clk);
        inf.amnt_valid =    'b0;
        inf.D.d_money =     'bx;
    end
    else if (action == Check) begin     // argument: None
        ;
    end
    else if (action == Use_item) begin  // argument: item category
        // random item
        assert(rand_item.randomize());
        category = Itm;
        item = rand_item.item;

        // random gap before argument
        gap = $urandom_range(1,5);
        repeat(gap) @(negedge clk);

        // specify signals
        inf.item_valid =    'b1;
        inf.D =             item;
        @(negedge clk);
        inf.item_valid =    'b0;
        inf.D =             'bx;
    end
    else if (action == Attack) begin    // argument: other player's id
        // random defender
        do begin
            // SPEC 0.12 Attacker and defender can’t be the same player.
            assert(rand_defender.randomize());
            def_player = rand_defender.player_id;
        end while (def_player == player);

        // random gap before argument
        gap = $urandom_range(1,5);
        repeat(gap) @(negedge clk);

        // specify signals
        inf.id_valid =      'b1;
        inf.D =             def_player;
        @(negedge clk);
        inf.id_valid =      'b0;
        inf.D =             'bx;
    end

    if (DEBUG_MODE) begin
        $display($time);
        $display("Input Action:");
        $display("player : %p",     player);
        $display("action : %p",     action);
        $display("category : %p",   category);
        $display("pkm_type : %p",   pkm_type);
        $display("item : %p",       item);
        $display("money : %p",      money);
        $display("def_player : %p", def_player);
        $display();
    end
end endtask

task compute_answer; begin
    // Compute Player Information Using Signals Generated from input_action Task

    // Load Player Information from DRAM First
    player_info = {
        golden_DRAM[65536 + player*8 + 0],
        golden_DRAM[65536 + player*8 + 1],
        golden_DRAM[65536 + player*8 + 2],
        golden_DRAM[65536 + player*8 + 3],
        golden_DRAM[65536 + player*8 + 4],
        golden_DRAM[65536 + player*8 + 5],
        golden_DRAM[65536 + player*8 + 6],
        golden_DRAM[65536 + player*8 + 7]
    };
    if (action == Attack) begin
        def_player_info = {
            golden_DRAM[65536 + def_player*8 + 0],
            golden_DRAM[65536 + def_player*8 + 1],
            golden_DRAM[65536 + def_player*8 + 2],
            golden_DRAM[65536 + def_player*8 + 3],
            golden_DRAM[65536 + def_player*8 + 4],
            golden_DRAM[65536 + def_player*8 + 5],
            golden_DRAM[65536 + def_player*8 + 6],
            golden_DRAM[65536 + def_player*8 + 7]
        };
    end

    if (DEBUG_MODE) begin
        $display("Before Computation");
        $display("player_info: %p",     player_info);
        $display("Bracer buff: %d",     bracer_buff);
        $display("def_player_info: %p", def_player_info);
        $display();
    end

    // golden output signals
    golden_err =    No_Err;
    golden_output = 64'b0;

    // Compute Action Result
    if (action == Buy) begin
        // identify error:  Out of money, Already have a pokemon, Bag is full
        if ( player_info.bag_info.money < ((category == Pkm) ? PKM_PRICE(Buy, Lowest, pkm_type) : ITM_PRICE(Buy, item)) )   golden_err = Out_of_money;
        else if ( (category == Pkm) && (player_info.pkm_info.stage != No_stage) )                                           golden_err = Already_Have_PKM;
        else if ( (category == Itm) && (
            ( (player_info.bag_info.berry_num == 15)     && (item == Berry)         ) ||
            ( (player_info.bag_info.medicine_num == 15)  && (item == Medicine)      ) ||
            ( (player_info.bag_info.candy_num == 15)     && (item == Candy)         ) ||
            ( (player_info.bag_info.bracer_num == 15)    && (item == Bracer)        ) ||
            ( (player_info.bag_info.stone != No_stone)   && (item == Water_stone)   ) ||
            ( (player_info.bag_info.stone != No_stone)   && (item == Fire_stone)    ) ||
            ( (player_info.bag_info.stone != No_stone)   && (item == Thunder_stone) )
        ) )                                                                                                                 golden_err = Bag_is_full;
        else begin
                                                                                                                            golden_err = No_Err;

            // compute buy result
            player_info.bag_info.money = player_info.bag_info.money - ((category == Pkm) ? PKM_PRICE(Buy, Lowest, pkm_type) : ITM_PRICE(Buy, item));
            if (category == Pkm) begin
                player_info.pkm_info.stage =    Lowest;
                player_info.pkm_info.pkm_type = pkm_type;
                player_info.pkm_info.hp =       PKM_HP(Lowest, pkm_type);
                player_info.pkm_info.atk =      PKM_ATK(Lowest, pkm_type);
                player_info.pkm_info.exp =      0;
            end
            else begin
                if (item == Berry)              player_info.bag_info.berry_num = player_info.bag_info.berry_num + 1;
                else if (item == Medicine)      player_info.bag_info.medicine_num = player_info.bag_info.medicine_num + 1;
                else if (item == Candy)         player_info.bag_info.candy_num = player_info.bag_info.candy_num + 1;
                else if (item == Bracer)        player_info.bag_info.bracer_num = player_info.bag_info.bracer_num + 1;
                else if (item == Water_stone)   player_info.bag_info.stone = W_stone;
                else if (item == Fire_stone)    player_info.bag_info.stone = F_stone;
                else if (item == Thunder_stone) player_info.bag_info.stone = T_stone;
            end

            // update player information
            {
                golden_DRAM[65536 + player*8 + 0],
                golden_DRAM[65536 + player*8 + 1],
                golden_DRAM[65536 + player*8 + 2],
                golden_DRAM[65536 + player*8 + 3],
                golden_DRAM[65536 + player*8 + 4],
                golden_DRAM[65536 + player*8 + 5],
                golden_DRAM[65536 + player*8 + 6],
                golden_DRAM[65536 + player*8 + 7]
            } = player_info;
        end
    end
    else if (action == Sell) begin
        // identify error:  Do not have a Pokemon, Do not have item, Pokemon is in the lowest stage
        if ( (category == Pkm) && (player_info.pkm_info.stage == No_stage) )    golden_err = Not_Having_PKM;
        else if ( (category == Itm) && (
            ( (player_info.bag_info.berry_num == 0)         && (item == Berry)         ) ||
            ( (player_info.bag_info.medicine_num == 0)      && (item == Medicine)      ) ||
            ( (player_info.bag_info.candy_num == 0)         && (item == Candy)         ) ||
            ( (player_info.bag_info.bracer_num == 0)        && (item == Bracer)        ) ||
            ( (player_info.bag_info.stone != W_stone)       && (item == Water_stone)   ) ||
            ( (player_info.bag_info.stone != F_stone)       && (item == Fire_stone)    ) ||
            ( (player_info.bag_info.stone != T_stone)       && (item == Thunder_stone) )
        ) )                                                                     golden_err = Not_Having_Item;
        else if ( (category == Pkm) && (player_info.pkm_info.stage == Lowest) ) golden_err = Has_Not_Grown;
        else begin
                                                                                golden_err = No_Err;


            assert (player_info.bag_info.money + (
                    (category == Pkm) ? 
                    PKM_PRICE(Sell, player_info.pkm_info.stage, player_info.pkm_info.pkm_type) : 
                    ITM_PRICE(Sell, item)
            ) <= 16384-1 )
            else begin
                $display("SPEC 0.26. The money of each player won’t overflow. Your pattern should avoid this situation.");
                $display("%d + %d > 16383", player_info.bag_info.money, 
                    (category == Pkm) ? 
                        PKM_PRICE(Sell, player_info.pkm_info.stage, player_info.pkm_info.pkm_type) : 
                        ITM_PRICE(Sell, item)
                );
                $finish;
            end

            // compute sell result
            player_info.bag_info.money = player_info.bag_info.money + (
                (category == Pkm) ? 
                PKM_PRICE(Sell, player_info.pkm_info.stage, player_info.pkm_info.pkm_type) : 
                ITM_PRICE(Sell, item)
            );
            if (category == Pkm) begin
                player_info.pkm_info = 32'b0;
                // bracer effect disappears after selling pokemon (2/4)
                bracer_buff = 0;
            end 
            else begin
                if (item == Berry)              player_info.bag_info.berry_num = player_info.bag_info.berry_num - 1;
                else if (item == Medicine)      player_info.bag_info.medicine_num = player_info.bag_info.medicine_num - 1;
                else if (item == Candy)         player_info.bag_info.candy_num = player_info.bag_info.candy_num - 1;
                else if (item == Bracer)        player_info.bag_info.bracer_num = player_info.bag_info.bracer_num - 1;
                else if (item == Water_stone)   player_info.bag_info.stone = No_stone;
                else if (item == Fire_stone)    player_info.bag_info.stone = No_stone;
                else if (item == Thunder_stone) player_info.bag_info.stone = No_stone;
            end

            // update player information
            {
                golden_DRAM[65536 + player*8 + 0],
                golden_DRAM[65536 + player*8 + 1],
                golden_DRAM[65536 + player*8 + 2],
                golden_DRAM[65536 + player*8 + 3],
                golden_DRAM[65536 + player*8 + 4],
                golden_DRAM[65536 + player*8 + 5],
                golden_DRAM[65536 + player*8 + 6],
                golden_DRAM[65536 + player*8 + 7]
            } = player_info;

        end
    end
    else if (action == Deposit) begin
        // identify error:  None
        begin
            golden_err = No_Err;

            assert (player_info.bag_info.money + money <= 16384-1 )
            else begin
                $display("SPEC 0.26. The money of each player won’t overflow. Your pattern should avoid this situation.");
                $display("%d + %d > 16383", player_info.bag_info.money, money);
                $finish;
            end

            // compute deposit result
            player_info.bag_info.money = player_info.bag_info.money + money;

            // update player information
            {
                golden_DRAM[65536 + player*8 + 0],
                golden_DRAM[65536 + player*8 + 1],
                golden_DRAM[65536 + player*8 + 2],
                golden_DRAM[65536 + player*8 + 3],
                golden_DRAM[65536 + player*8 + 4],
                golden_DRAM[65536 + player*8 + 5],
                golden_DRAM[65536 + player*8 + 6],
                golden_DRAM[65536 + player*8 + 7]
            } = player_info;

        end
    end
    else if (action == Check) begin
        // identify error:  None
        begin
            golden_err = No_Err;
        end
    end
    else if (action == Use_item) begin
        // identify error:  Do not have a Pokemon, Do not have item
        if (player_info.pkm_info.stage == No_stage)                             golden_err = Not_Having_PKM;
        else if (
            ( (player_info.bag_info.berry_num == 0)         && (item == Berry)         ) ||
            ( (player_info.bag_info.medicine_num == 0)      && (item == Medicine)      ) ||
            ( (player_info.bag_info.candy_num == 0)         && (item == Candy)         ) ||
            ( (player_info.bag_info.bracer_num == 0)        && (item == Bracer)        ) ||
            ( (player_info.bag_info.stone != W_stone)       && (item == Water_stone)   ) ||
            ( (player_info.bag_info.stone != F_stone)       && (item == Fire_stone)    ) ||
            ( (player_info.bag_info.stone != T_stone)       && (item == Thunder_stone) )
        )                                                                       golden_err = Not_Having_Item;
        else begin
                                                                                golden_err = No_Err;

            if (item == Berry) begin
                player_info.bag_info.berry_num = player_info.bag_info.berry_num - 1;
                updated_hp = PKM_HP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                updated_hp = (player_info.pkm_info.hp + 32 <= updated_hp) ? player_info.pkm_info.hp + 32 : updated_hp;
                player_info.pkm_info.hp = updated_hp;
            end
            else if (item == Medicine) begin
                player_info.bag_info.medicine_num = player_info.bag_info.medicine_num - 1;
                player_info.pkm_info.hp = PKM_HP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
            end
            else if (item == Candy) begin
                player_info.bag_info.candy_num = player_info.bag_info.candy_num - 1;
                if ( player_info.pkm_info.exp + 15 < PKM_EXP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type) ) begin
                    // not overflow
                    player_info.pkm_info.exp = player_info.pkm_info.exp + 15;
                end
                else begin
                    // overflow
                    if ((player_info.pkm_info.stage == Highest) || (player_info.pkm_info.pkm_type == Normal)) begin
                        // not upgradable
                        player_info.pkm_info.exp = PKM_EXP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                    end
                    else begin
                        // upgradable
                        player_info.pkm_info.stage = (player_info.pkm_info.stage == Lowest) ? Middle : Highest;
                        player_info.pkm_info.hp = PKM_HP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                        player_info.pkm_info.atk = PKM_ATK(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                        player_info.pkm_info.exp = 0;
                        bracer_buff = 0;    // bracer effect disappears after evolution (3/4)
                    end
                end
            end
            else if (item == Bracer) begin
                player_info.bag_info.bracer_num = player_info.bag_info.bracer_num - 1;
                bracer_buff = 1;
            end
            else if (
                (item == Water_stone)   ||
                (item == Fire_stone)    ||
                (item == Thunder_stone)
            ) begin
                player_info.bag_info.stone = No_stone;
                if (
                    (player_info.pkm_info.pkm_type == Normal) &&
                    (player_info.pkm_info.exp == PKM_EXP(Lowest, Normal))
                ) begin // upgradable
                    player_info.pkm_info.stage = Highest;
                    player_info.pkm_info.pkm_type = (item == Water_stone) ? Water : (item == Fire_stone) ? Fire : Electric;
                    player_info.pkm_info.hp = PKM_HP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                    player_info.pkm_info.atk = PKM_ATK(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                    player_info.pkm_info.exp = 0;
                    bracer_buff = 0;    // bracer effect disappears after evolution (3/4)
                end
            end

            // update player information
            {
                golden_DRAM[65536 + player*8 + 0],
                golden_DRAM[65536 + player*8 + 1],
                golden_DRAM[65536 + player*8 + 2],
                golden_DRAM[65536 + player*8 + 3],
                golden_DRAM[65536 + player*8 + 4],
                golden_DRAM[65536 + player*8 + 5],
                golden_DRAM[65536 + player*8 + 6],
                golden_DRAM[65536 + player*8 + 7]
            } = player_info;
        end
    end
    else if (action == Attack) begin
        // identify error:  Do not have a Pokemon, HP is zero
        if ( (player_info.pkm_info.stage == No_stage) || (def_player_info.pkm_info.stage == No_stage) ) golden_err = Not_Having_PKM;
        else if ( (player_info.pkm_info.hp == 0) || (def_player_info.pkm_info.hp == 0) )                golden_err = HP_is_Zero;
        else begin
                                                                                                        golden_err = No_Err;

            // compute attack result
            // compute effective damage
            effective_dmg = PKM_ATK(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
            if (bracer_buff) effective_dmg = effective_dmg + 32;
            case ({player_info.pkm_info.pkm_type,def_player_info.pkm_info.pkm_type})
                {Grass,     Water}, 
                {Fire,      Grass}, 
                {Water,     Fire}, 
                {Electric,  Water}: effective_dmg = effective_dmg * 2; 
                
                {Grass,     Fire},
                {Fire,      Water},
                {Water,     Grass},
                {Electric,  Grass},
                {Grass,     Grass},
                {Fire,      Fire},
                {Water,     Water},
                {Electric,  Electric}: effective_dmg = effective_dmg / 2;
                default: effective_dmg = effective_dmg;
            endcase

            // compute battle result
            player_info.pkm_info.exp = player_info.pkm_info.exp + ATK_EXP(def_player_info.pkm_info.stage);
            bracer_buff = 0;            // bracer effect disappears after attacking (1/4)

            if (def_player_info.pkm_info.hp <= effective_dmg)   def_player_info.pkm_info.hp = 0;
            else                                                def_player_info.pkm_info.hp = def_player_info.pkm_info.hp - effective_dmg;
            def_player_info.pkm_info.exp = def_player_info.pkm_info.exp + DEF_EXP(player_info.pkm_info.stage);
            

            if (player_info.pkm_info.exp >= PKM_EXP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type)) begin
                // overflow
                if ((player_info.pkm_info.stage == Highest) || (player_info.pkm_info.pkm_type == Normal)) begin
                    // not upgradable
                    player_info.pkm_info.exp = PKM_EXP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                end
                else begin
                    // upgradable
                    player_info.pkm_info.stage = (player_info.pkm_info.stage == Lowest) ? Middle : Highest;
                    player_info.pkm_info.hp = PKM_HP(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                    player_info.pkm_info.atk = PKM_ATK(player_info.pkm_info.stage, player_info.pkm_info.pkm_type);
                    player_info.pkm_info.exp = 0;
                    bracer_buff = 0;    // bracer effect disappears after evolution (3/4)
                end
            end

            if (def_player_info.pkm_info.exp >= PKM_EXP(def_player_info.pkm_info.stage, def_player_info.pkm_info.pkm_type)) begin
                // overflow
                if ((def_player_info.pkm_info.stage == Highest) || (def_player_info.pkm_info.pkm_type == Normal)) begin
                    // not upgradable
                    def_player_info.pkm_info.exp = PKM_EXP(def_player_info.pkm_info.stage, def_player_info.pkm_info.pkm_type);
                end
                else begin
                    // upgradable
                    def_player_info.pkm_info.stage = (def_player_info.pkm_info.stage == Lowest) ? Middle : Highest;
                    def_player_info.pkm_info.hp = PKM_HP(def_player_info.pkm_info.stage, def_player_info.pkm_info.pkm_type);
                    def_player_info.pkm_info.atk = PKM_ATK(def_player_info.pkm_info.stage, def_player_info.pkm_info.pkm_type);
                    def_player_info.pkm_info.exp = 0;
                end
            end

            // update player information
            {
                golden_DRAM[65536 + player*8 + 0],
                golden_DRAM[65536 + player*8 + 1],
                golden_DRAM[65536 + player*8 + 2],
                golden_DRAM[65536 + player*8 + 3],
                golden_DRAM[65536 + player*8 + 4],
                golden_DRAM[65536 + player*8 + 5],
                golden_DRAM[65536 + player*8 + 6],
                golden_DRAM[65536 + player*8 + 7]
            } = player_info;
            {
                golden_DRAM[65536 + def_player*8 + 0],
                golden_DRAM[65536 + def_player*8 + 1],
                golden_DRAM[65536 + def_player*8 + 2],
                golden_DRAM[65536 + def_player*8 + 3],
                golden_DRAM[65536 + def_player*8 + 4],
                golden_DRAM[65536 + def_player*8 + 5],
                golden_DRAM[65536 + def_player*8 + 6],
                golden_DRAM[65536 + def_player*8 + 7]
            } = def_player_info;
        end
    end

    // action complete and update output
    if (bracer_buff) player_info.pkm_info.atk = player_info.pkm_info.atk + 32;
    if (golden_err == No_Err) begin
        if (action != Attack)   golden_output = player_info;
        else                    golden_output = {
                                                    player_info.pkm_info,
                                                    def_player_info.pkm_info
                                                };
    end
    else                        golden_output = 0;
    if (bracer_buff) player_info.pkm_info.atk = player_info.pkm_info.atk - 32;

    if (DEBUG_MODE) begin
        $display("The Golden Answer");
        $display("player_info: %p",     player_info);
        $display("Bracer buff: %d",     bracer_buff);
        $display("def_player_info: %p", def_player_info);
        $display("err_msg: %p",         golden_err);
        $display("out_info: %h",        golden_output);
        $display();
    end
end endtask

task check_output; begin
    calc_cycle = 0;
    while (inf.out_valid === 0) begin
        calc_cycle = calc_cycle + 1;
        @(negedge clk);
    end
    total_calc_cycle = total_calc_cycle + calc_cycle; 
    if (
        (inf.out_valid !== 1)                       ||
        (inf.complete !== (golden_err == No_Err))   ||
        (inf.out_info !== golden_output)            ||
        (inf.err_msg !== golden_err)
    ) begin
        $display("Wrong Answer");
        $finish;
        fail_task;
        $display("---------------------------------------------");
        $display("              SPEC 16 IS FAIL!               ");
        $display("---------------------------------------------");
        $display("SPEC 16. Check the output signal only when the out_valid is high.");
        if (inf.out_valid !== 1)                        $display("The value of out_valid should be %b rather than %b",  1,                      inf.out_valid);
        if (inf.complete !== (golden_err == No_Err))    $display("The value of complete should be %b rather than %b",   (golden_err == No_Err), inf.complete);
        if (inf.err_msg !== golden_err)                 $display("The value of err_msg should be %p rather than %p",    golden_err,             inf.err_msg);
        if (inf.out_info !== golden_output)             $display("The value of out_info should be %h rather than %h",   golden_output,          inf.out_info);           
        $display($time);
        $finish;
    end

    // @(negedge clk); // not stepping the clock here
end endtask

task YOU_PASS_task;begin
    pass_task;
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $display ("                                                  Congratulations!                                                    ");
    $display ("                                           You have passed all patterns!                                              ");
    $display ("                                                                                                                      ");
    $display ("                                        Your execution cycles   = %5d cycles                                          ", total_calc_cycle);
    $display ("                                        Your clock period       = %.1f ns                                             ", simulation_cycle);
    $display ("                                        Total latency           = %.1f ns                                             ", total_calc_cycle * simulation_cycle );
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $finish; 
end endtask

task pass_task;
    $display("                                                             \033[33m`-                                                                            ");        
    $display("                                                             /NN.                                                                           ");        
    $display("                                                            sMMM+                                                                           ");        
    $display(" .``                                                       sMMMMy                                                                           ");        
    $display(" oNNmhs+:-`                                               oMMMMMh                                                                           ");        
    $display("  /mMMMMMNNd/:-`                                         :+smMMMh                                                                           ");        
    $display("   .sNMMMMMN::://:-`                                    .o--:sNMy                                                                           ");        
    $display("     -yNMMMM:----::/:-.                                 o:----/mo                                                                           ");        
    $display("       -yNMMo--------://:.                             -+------+/                                                                           ");        
    $display("         .omd/::--------://:`                          o-------o.                                                                           ");        
    $display("           `/+o+//::-------:+:`                       .+-------y                                                                            ");        
    $display("              .:+++//::------:+/.---------.`          +:------/+                                                                            ");        
    $display("                 `-/+++/::----:/:::::::::::://:-.     o------:s.          \033[37m:::::----.           -::::.          `-:////:-`     `.:////:-.    \033[33m");        
    $display("                    `.:///+/------------------:::/:- `o-----:/o          \033[37m.NNNNNNNNNNds-       -NNNNNd`       -smNMMMMMMNy   .smNNMMMMMNh    \033[33m");        
    $display("                         :+:----------------------::/:s-----/s.          \033[37m.MMMMo++sdMMMN-     `mMMmMMMs      -NMMMh+///oys  `mMMMdo///oyy    \033[33m");        
    $display("                        :/---------------------------:++:--/++           \033[37m.MMMM.   `mMMMy     yMMM:dMMM/     +MMMM:      `  :MMMM+`     `    \033[33m");        
    $display("                       :/---///:-----------------------::-/+o`           \033[37m.MMMM.   -NMMMo    +MMMs -NMMm.    .mMMMNdo:.     `dMMMNds/-`      \033[33m");        
    $display("                      -+--/dNs-o/------------------------:+o`            \033[37m.MMMMyyyhNMMNy`   -NMMm`  sMMMh     .odNMMMMNd+`   `+dNMMMMNdo.    \033[33m");        
    $display("                     .o---yMMdsdo------------------------:s`             \033[37m.MMMMNmmmdho-    `dMMMdooosMMMM+      `./sdNMMMd.    `.:ohNMMMm-   \033[33m");        
    $display("                    -yo:--/hmmds:----------------//:------o              \033[37m.MMMM:...`       sMMMMMMMMMMMMMN-  ``     `:MMMM+ ``      -NMMMs   \033[33m");        
    $display("                   /yssy----:::-------o+-------/h/-hy:---:+              \033[37m.MMMM.          /MMMN:------hMMMd` +dy+:::/yMMMN- :my+:::/sMMMM/   \033[33m");        
    $display("                  :ysssh:------//////++/-------sMdyNMo---o.              \033[37m.MMMM.         .mMMMs       .NMMMs /NMMMMMMMMmh:  -NMMMMMMMMNh/    \033[33m");        
    $display("                  ossssh:-------ddddmmmds/:----:hmNNh:---o               \033[37m`::::`         .::::`        -:::: `-:/++++/-.     .:/++++/-.      \033[33m");        
    $display("                  /yssyo--------dhhyyhhdmmhy+:---://----+-                                                                                  ");        
    $display("                  `yss+---------hoo++oosydms----------::s    `.....-.                                                                       ");        
    $display("                   :+-----------y+++++++oho--------:+sssy.://:::://+o.                                                                      ");        
    $display("                    //----------y++++++os/--------+yssssy/:--------:/s-                                                                     ");        
    $display("             `..:::::s+//:::----+s+++ooo:--------+yssssy:-----------++                                                                      ");        
    $display("           `://::------::///+/:--+soo+:----------ssssys/---------:o+s.``                                                                    ");        
    $display("          .+:----------------/++/:---------------:sys+----------:o/////////::::-...`                                                        ");        
    $display("          o---------------------oo::----------::/+//---------::o+--------------:/ohdhyo/-.``                                                ");        
    $display("          o---------------------/s+////:----:://:---------::/+h/------------------:oNMMMMNmhs+:.`                                           ");        
    $display("          -+:::::--------------:s+-:::-----------------:://++:s--::------------::://sMMMMMMMMMMNds/`                                        ");        
    $display("           .+++/////////////+++s/:------------------:://+++- :+--////::------/ydmNNMMMMMMMMMMMMMMmo`                                        ");        
    $display("             ./+oo+++oooo++/:---------------------:///++/-   o--:///////::----sNMMMMMMMMMMMMMMMmo.                                          ");        
    $display("                o::::::--------------------------:/+++:`    .o--////////////:--+mMMMMMMMMMMMMmo`                                            ");        
    $display("               :+--------------------------------/so.       +:-:////+++++///++//+mMMMMMMMMMmo`                                              ");        
    $display("              .s----------------------------------+: ````` `s--////o:.-:/+syddmNMMMMMMMMMmo`                                                ");        
    $display("              o:----------------------------------s. :s+/////--//+o-       `-:+shmNNMMMNs.                                                  ");        
    $display("             //-----------------------------------s` .s///:---:/+o.               `-/+o.                                                    ");        
    $display("            .o------------------------------------o.  y///+//:/+o`                                                                          ");        
    $display("            o-------------------------------------:/  o+//s//+++`                                                                           ");        
    $display("           //--------------------------------------s+/o+//s`                                                                                ");        
    $display("          -+---------------------------------------:y++///s                                                                                 ");        
    $display("          o-----------------------------------------oo/+++o                                                                                 ");        
    $display("         `s-----------------------------------------:s   ``                                                                                 ");        
    $display("          o-:::::------------------:::::-------------o.                                                                                     ");        
    $display("          .+//////////::::::://///////////////:::----o`                                                                                     ");        
    $display("          `:soo+///////////+++oooooo+/////////////:-//                                                                                      ");        
    $display("       -/os/--:++/+ooo:::---..:://+ooooo++///////++so-`                                                                                     ");        
    $display("      syyooo+o++//::-                 ``-::/yoooo+/:::+s/.                                                                                  ");        
    $display("       `..``                                `-::::///:++sys:                                                                                ");        
    $display("                                                    `.:::/o+  \033[37m                                                                              ");	
    $display("********************************************************************");
    $display("                        \033[0;38;5;219mCongratulations!\033[m      ");
    $display("                 \033[0;38;5;219mYou have passed all patterns!\033[m");
    $display("********************************************************************");
    // $finish;
endtask

task fail_task; 
    $display("\033[33m	                                                         .:                                                                                         ");      
    $display("                                                   .:                                                                                                 ");
    $display("                                                  --`                                                                                                 ");
    $display("                                                `--`                                                                                                  ");
    $display("                 `-.                            -..        .-//-                                                                                      ");
    $display("                  `.:.`                        -.-     `:+yhddddo.                                                                                    ");
    $display("                    `-:-`             `       .-.`   -ohdddddddddh:                                                                                   ");
    $display("                      `---`       `.://:-.    :`- `:ydddddhhsshdddh-                       \033[31m.yhhhhhhhhhs       /yyyyy`       .yhhy`   +yhyo           \033[33m");
    $display("                        `--.     ./////:-::` `-.--yddddhs+//::/hdddy`                      \033[31m-MMMMNNNNNNh      -NMMMMMs       .MMMM.   sMMMh           \033[33m");
    $display("                          .-..   ////:-..-// :.:oddddho:----:::+dddd+                      \033[31m-MMMM-......     `dMMmhMMM/      .MMMM.   sMMMh           \033[33m");
    $display("                           `-.-` ///::::/::/:/`odddho:-------:::sdddh`                     \033[31m-MMMM.           sMMM/.NMMN.     .MMMM.   sMMMh           \033[33m");
    $display("             `:/+++//:--.``  .--..+----::://o:`osss/-.--------::/dddd/             ..`     \033[31m-MMMMysssss.    /MMMh  oMMMh     .MMMM.   sMMMh           \033[33m");
    $display("             oddddddddddhhhyo///.-/:-::--//+o-`:``````...------::dddds          `.-.`      \033[31m-MMMMMMMMMM-   .NMMN-``.mMMM+    .MMMM.   sMMMh           \033[33m");
    $display("            .ddddhhhhhddddddddddo.//::--:///+/`.````````..``...-:ddddh       `.-.`         \033[31m-MMMM:.....`  `hMMMMmmmmNMMMN-   .MMMM.   sMMMh           \033[33m");
    $display("            /dddd//::///+syhhdy+:-`-/--/////+o```````.-.......``./yddd`   `.--.`           \033[31m-MMMM.        oMMMmhhhhhhdMMMd`  .MMMM.   sMMMh```````    \033[33m");
    $display("            /dddd:/------:://-.`````-/+////+o:`````..``     `.-.``./ym.`..--`              \033[31m-MMMM.       :NMMM:      .NMMMs  .MMMM.   sMMMNmmmmmms    \033[33m");
    $display("            :dddd//--------.`````````.:/+++/.`````.` `.-      `-:.``.o:---`                \033[31m.dddd`       yddds        /dddh. .dddd`   +ddddddddddo    \033[33m");
    $display("            .ddddo/-----..`........`````..```````..  .-o`       `:.`.--/-      ``````````` \033[31m ````        ````          ````   ````     ``````````     \033[33m");
    $display("             ydddh/:---..--.````.`.-.````````````-   `yd:        `:.`...:` `................`                                                         ");
    $display("             :dddds:--..:.     `.:  .-``````````.:    +ys         :-````.:...```````````````..`                                                       ");
    $display("              sdddds:.`/`      ``s.  `-`````````-/.   .sy`      .:.``````-`````..-.-:-.````..`-                                                       ");
    $display("              `ydddd-`.:       `sh+   /:``````````..`` +y`   `.--````````-..---..``.+::-.-``--:                                                       ");
    $display("               .yddh``-.        oys`  /.``````````````.-:.`.-..`..```````/--.`      /:::-:..--`                                                       ");
    $display("                .sdo``:`        .sy. .:``````````````````````````.:```...+.``       -::::-`.`                                                         ");
    $display(" ````.........```.++``-:`        :y:.-``````````````....``.......-.```..::::----.```  ``                                                              ");
    $display("`...````..`....----:.``...````  ``::.``````.-:/+oosssyyy:`.yyh-..`````.:` ````...-----..`                                                             ");
    $display("                 `.+.``````........````.:+syhdddddddddddhoyddh.``````--              `..--.`                                                          ");
    $display("            ``.....--```````.```````.../ddddddhhyyyyyyyhhhddds````.--`             ````   ``                                                          ");
    $display("         `.-..``````-.`````.-.`.../ss/.oddhhyssssooooooossyyd:``.-:.         `-//::/++/:::.`                                                          ");
    $display("       `..```````...-::`````.-....+hddhhhyssoo+++//////++osss.-:-.           /++++o++//s+++/                                                          ");
    $display("     `-.```````-:-....-/-``````````:hddhsso++/////////////+oo+:`             +++::/o:::s+::o            \033[31m     `-/++++:-`                              \033[33m");
    $display("    `:````````./`  `.----:..````````.oysso+///////////////++:::.             :++//+++/+++/+-            \033[31m   :ymMMMMMMMMms-                            \033[33m");
    $display("    :.`-`..```./.`----.`  .----..`````-oo+////////////////o:-.`-.            `+++++++++++/.             \033[31m `yMMMNho++odMMMNo                           \033[33m");
    $display("    ..`:..-.`.-:-::.`        `..-:::::--/+++////////////++:-.```-`            +++++++++o:               \033[31m hMMMm-      /MMMMo  .ssss`/yh+.syyyyyyyyss. \033[33m");
    $display("     `.-::-:..-:-.`                 ```.+::/++//++++++++:..``````:`          -++++++++oo                \033[31m:MMMM:        yMMMN  -MMMMdMNNs-mNNNNNMMMMd` \033[33m");
    $display("        `   `--`                        /``...-::///::-.`````````.: `......` ++++++++oy-                \033[31m+MMMM`        +MMMN` -MMMMh:--. ````:mMMNs`  \033[33m");
    $display("           --`                          /`````````````````````````/-.``````.::-::::::/+                 \033[31m:MMMM:        yMMMm  -MMMM`       `oNMMd:    \033[33m");
    $display("          .`                            :```````````````````````--.`````````..````.``/-                 \033[31m dMMMm:`    `+MMMN/  -MMMN       :dMMNs`     \033[33m");
    $display("                                        :``````````````````````-.``.....````.```-::-.+                  \033[31m `yNMMMdsooymMMMm/   -MMMN     `sMMMMy/////` \033[33m");
    $display("                                        :.````````````````````````-:::-::.`````-:::::+::-.`             \033[31m   -smNMMMMMNNd+`    -NNNN     hNNNNNNNNNNN- \033[33m");
    $display("                                `......../```````````````````````-:/:   `--.```.://.o++++++/.           \033[31m      .:///:-`       `----     ------------` \033[33m");
    $display("                              `:.``````````````````````````````.-:-`      `/````..`+sssso++++:                                                        ");
    $display("                              :`````.---...`````````````````.--:-`         :-````./ysoooss++++.                                                       ");
    $display("                              -.````-:/.`.--:--....````...--:/-`            /-..-+oo+++++o++++.                                                       ");
    $display("             `:++/:.`          -.```.::      `.--:::::://:::::.              -:/o++++++++s++++                                                        ");
    $display("           `-+++++++++////:::/-.:.```.:-.`              :::::-.-`               -+++++++o++++.                                                        ");
    $display("           /++osoooo+++++++++:`````````.-::.             .::::.`-.`              `/oooo+++++.                                                         ");
    $display("           ++oysssosyssssooo/.........---:::               -:::.``.....`     `.:/+++++++++:                                                           ");
    $display("           -+syoooyssssssyo/::/+++++/+::::-`                 -::.``````....../++++++++++:`                                                            ");
    $display("             .:///-....---.-..-.----..`                        `.--.``````````++++++/:.                                                               ");
    $display("                                                                   `........-:+/:-.`                                                            \033[37m      ");
endtask

endprogram

