import random

Stage = {
    0: 'No_stage',
    1: 'Lowest',
    2: 'Middle',
    4: 'Highest'
}

PKM_Type = {
    0: 'No_type',
    1: 'Grass',
    2: 'Fire',
    4: 'Water',
    8: 'Electric',
    5: 'Normal'
}

HP = {
    (0, 0): 0,

    (1, 1): 128,
    (1, 2): 119,
    (1, 4): 125,
    (1, 8): 122,
    (1, 5): 124,

    (2, 1): 192,
    (2, 2): 177,
    (2, 4): 187,
    (2, 8): 182,

    (4, 1): 254,
    (4, 2): 225,
    (4, 4): 245,
    (4, 8): 235
}

ATK = {
    (0, 0): 0,

    (1, 1): 63,
    (1, 2): 64,
    (1, 4): 60,
    (1, 8): 65,
    (1, 5): 62,

    (2, 1): 94,
    (2, 2): 96,
    (2, 4): 89,
    (2, 8): 97,

    (4, 1): 123,
    (4, 2): 127,
    (4, 4): 113,
    (4, 8): 124
}

EXP = {
    (0, 0): 0,

    (1, 1): 32,
    (1, 2): 30,
    (1, 4): 28,
    (1, 8): 26,
    (1, 5): 29,

    (2, 1): 63,
    (2, 2): 59,
    (2, 4): 55,
    (2, 8): 51
}

class Bag(object):
    '''
         4 bits: # berry
         4 bits: # medicine
         4 bits: # candy
         4 bits: # bracer
         2 bits: stone code
        14 bits: # money
    '''
    def __init__(self):
        # full or empty to make enhance coverage, or simply using random.randint(0,2** 4-1)
        self.berry_num =    2**4-1 if random.randint(0,1) else 0
        self.medicine_num = 2**4-1 if random.randint(0,1) else 0
        self.candy_num =    2**4-1 if random.randint(0,1) else 0
        self.bracer_num =   2**4-1 if random.randint(0,1) else 0
        self.stone =        random.randint(0,2** 2-1) if random.randint(0,1) else 0
        
        # limited range to avoid money overflow after selling or despositing
        # random.randint(0,2**14-1)
        self.money =        1024 if random.randint(0,1) else 0
        
    def display(self):
        print(f"# Berry: {self.berry_num}")
        print(f"# Medicine: {self.medicine_num}")
        print(f"# Candy: {self.candy_num}")
        print(f"# Bracer: {self.bracer_num}")
        print(f"Stone Code: {self.stone}")
        print(f"# Money: {self.money}")

    def encode(self):
        bin_code = ''.join( \
            [
                bin(self.berry_num).lstrip('0b').zfill(4),
                bin(self.medicine_num).lstrip('0b').zfill(4),
                bin(self.candy_num).lstrip('0b').zfill(4),
                bin(self.bracer_num).lstrip('0b').zfill(4),
                bin(self.stone).lstrip('0b').zfill(2),
                bin(self.money).lstrip('0b').zfill(14),
            ]
        )
        assert len(bin_code) == 32
        hex_code = hex(int(bin_code, 2)).lstrip('0x').zfill(8).upper()
        hex_code = ' '.join([hex_code[i*2:(i+1)*2] for i in range(4)])
        return hex_code

class Pokemon(object):
    '''
        4 bits: stage
        4 bits: type
        8 bits: current hp
        8 bits: attack damage
        8 bits: experience
    '''
    def __init__(self):
        if random.randint(0,1): # have pokemon
            pkm_type = random.choice([1,2,4,8,5])
            if (PKM_Type[pkm_type] == 'Normal'):
                self.stage = 1
            else:
                # higher chance to assign Lowest Pokemon to enhabce the coverage of selling_pokemon_error
                self.stage = random.choice([1,1,1,1,1,2,4]) # [1,2,4]
            self.type = pkm_type     
            self.current_hp = random.randint(0,HP[(self.stage,self.type)]) if random.randint(0,1) else 0
            self.attack_damage = ATK[(self.stage,self.type)]
            if (Stage[self.stage] == 'Highest'):
                self.experience = 0
            else:
                self.experience = random.randint(0,EXP[(self.stage,self.type)]-1)
        else: # no pokemon
            self.stage = 0
            self.type = 0
            self.current_hp = 0
            self.attack_damage = 0
            self.experience = 0
    
    def display(self):
        print(f"Stage: {Stage[self.stage]}")
        print(f"Type: {PKM_Type[self.type]}")
        print(f"Current HP: {self.current_hp}")
        print(f"Attack Damage: {self.attack_damage}")
        print(f"Experience: {self.experience}")

    def encode(self):
        bin_code = ''.join( \
            [
                bin(self.stage).lstrip('0b').zfill(4),
                bin(self.type).lstrip('0b').zfill(4),
                bin(self.current_hp).lstrip('0b').zfill(8),
                bin(self.attack_damage).lstrip('0b').zfill(8),
                bin(self.experience).lstrip('0b').zfill(8),
            ]
        )
        assert len(bin_code) == 32
        hex_code = hex(int(bin_code, 2)).lstrip('0x').zfill(8).upper()
        hex_code = ' '.join([hex_code[i*2:(i+1)*2] for i in range(4)])
        return hex_code

class Player(object):
    def __init__(self):
        self.bag = Bag()
        self.pkm = Pokemon()
        
    def display(self):
        print("Bag Information:")
        self.bag.display()
        print()
        print("Pokemon Information:")
        self.pkm.display()
        print()
    
    def encode(self):
        pass

if __name__ == "__main__":
    with open('dram.dat','w') as f:
        random.seed(0)
        for player_no in range(256):
            player = Player()
            bag_addr = "@" + "1" + hex(player_no * 8 + 0).lstrip('0x').zfill(4).upper()
            f.write(bag_addr+'\n')
            f.write(player.bag.encode()+'\n')
            pkm_addr = "@" + "1" + hex(player_no * 8 + 4).lstrip('0x').zfill(4).upper()
            f.write(pkm_addr+'\n')
            f.write(player.pkm.encode()+'\n')