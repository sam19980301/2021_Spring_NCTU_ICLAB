from design_strategy import *

import random
import numpy as np
from tqdm import tqdm
from functools import reduce

pulse_dict = {
    0: [0.3, 0.0, 0.3, 0.0, 0.3],
    1: [0.3, 0.0, 0.3, 0.0, 0.3],
    2: [0.1, 0.4, 0.3, 0.2, 0.1],
    3: [0.1, 0.4, 0.3, 0.2, 0.1],
}

# Pattern Generation Functions

# Python pattern type 0: independent histograms
# Python pattern type 1: group histograms
# Python pattern type 2: convex histograms
# Python pattern type 3: concave histograms

def assert_type(type_):
    assert (type(type_) == int) and (type_ >= 0) and (type_ <= 3)

def generate_dist_list(type_,return_center=False):
    assert_type(type_)
    if (type_ == 0):
        dist = [random.randint(1,251) for i in range(16)]
    elif (type_ == 1):
        dist = [random.randint(1,251) for i in range(4)]
        dist = [
            dist[0], dist[0], dist[1], dist[1], 
            dist[0], dist[0], dist[1], dist[1], 
            dist[2], dist[2], dist[3], dist[3], 
            dist[2], dist[2], dist[3], dist[3]
        ]
    else:
        center = random.randint(0,15)
        dist = random.randint(1,236)
        if (type_== 3):
            if ((center%4==0) or (center%4==3) or (center//4==0) or (center//4==3)):
                dist += 15
            else:
                dist += 10
        offsets = [max(abs(center//4 - i//4), abs(center%4 - i%4)) for i in range(16)]
        if (type_ == 2):
            dist = [dist + offset * 5 for offset in offsets]
        else:
            dist = [dist - offset * 5 for offset in offsets]
    if (return_center and type_>=2):
        return dist, center
    else:
        return dist

def generate_single_stop(type_, dist):
    assert_type(type_)
    # assert (type(dist) == int) and (dist >= 1) and (dist <= (251 if type_ <= 1 else 236))
    probs = [0.3] * 255
    for i in range(5):
        probs[dist + i - 1] += pulse_dict[type_][i]
    stop = [np.random.binomial(1,i) for i in probs]
    return stop

def generate_stop_arr(type_, dist_list):
    '''
        input: distance list with length = 16
        output: binary numpy array with shape = (255, 16)
    '''    
    stop_arr = [generate_single_stop(type_, dist) for dist in dist_list]
    stop_arr = np.array(stop_arr).T.astype(int)
    return stop_arr

def stop_generator(type_,dist_list):
    assert_type(type_)
    if (type_ == 0):
        for i in range(15):
            yield generate_stop_arr(type_, dist_list)
    elif (type_ == 1):
        for i in range(4):
            yield generate_stop_arr(type_, dist_list)
    else:
        for i in range(7):
            yield generate_stop_arr(type_, dist_list)

# DRAM Writing Functions
def initialize_DRAM():
    dram_dict = {
        "@" + 
        hex(frame+16).lstrip('0x').zfill(2).upper() + 
        hex(hist_num).lstrip('0x').zfill(1).upper() + 
        hex(hist_dat).lstrip('0x').zfill(2).upper()
        : "00 00 00 00"
        for frame in range(32) for hist_num in range(16) for hist_dat in range(0,256,4)
    }
    return dram_dict

def update_DRAM(frame,stop_sum, dram_dict):
    for hist_num in range(16):
        for hist_dat in range(0,256,4):
            if (hist_dat!=252):
                dat = ' '.join([hex(stop_sum[hist_dat+i][-1-hist_num]).lstrip('0x').zfill(2).upper() for i in range(4)])
            else: # last index
                dat = ' '.join([hex(stop_sum[hist_dat+i][-1-hist_num]).lstrip('0x').zfill(2).upper() for i in range(3)])
                dat = dat +' 00'
            # print(dat)
            dram_dict[
                "@" + 
                hex(frame+16).lstrip('0x').zfill(2).upper() + 
                hex(hist_num).lstrip('0x').zfill(1).upper() + 
                hex(hist_dat).lstrip('0x').zfill(2).upper()
            ] = dat
    return dram_dict

def output_DRAM(file_name, dram_dict):
    with open(f'pattern_data/{file_name}.dat','w') as dram_f:
        for frame in range(32):
            for hist_num in range(16):
                for hist_dat in range(0,256,4):
                    addr = \
                        "@" + \
                        hex(frame+16).lstrip('0x').zfill(2).upper() + \
                        hex(hist_num).lstrip('0x').zfill(1).upper() + \
                        hex(hist_dat).lstrip('0x').zfill(2).upper()

                    dram_f.write(addr+'\n')
                    dram_f.write(dram_dict[addr]+'\n')

def generate_pattern_file(config):
    # Initalize DRAM
    dram_dict = initialize_DRAM()
    id_ = config['id_']
    with open(f'pattern_data/input_type{id_}.txt','w') as f:
        pat = config['total_pattern']
        f.write(str(pat))
        f.write('\n')
        # Type0
        if (config['starts_with_type_zero']):
            for frame_id in tqdm(range(32)):
                random.seed(config['init_seed'] + frame_id)
                np.random.seed(config['init_seed'] + frame_id)
                type_ = 0
                f.write(str(type_)+' '+str(frame_id))
                f.write('\n')
                while True:
                    dist_list = generate_dist_list(type_)
                    if (not config['all_corner'] or (min(dist_list) == 251 or min(dist_list) == 1)):
                        break
                stop_gen = stop_generator(type_, dist_list)
                stop_sum = reduce(lambda x,y:x+y, stop_gen)
                dram_dict = update_DRAM(frame_id,stop_sum,dram_dict)
                # write golden answer, from LSB to MSB
                # golden histogram
                for i in range(255):
                    for j in range(16-1,0-1,-1):
                        f.write(str(stop_sum[i][j])+' ')
                    f.write('\n')
                # golden distance
                for i in range(16-1,0-1,-1):
                    f.write(str(dist_list[i])+' ')
                f.write('\n')
                f.write('\n')

        output_DRAM(f'dram_type{id_}',dram_dict)

        for seed in tqdm(range(pat-32 if config['starts_with_type_zero'] else pat)):
            random.seed(config['init_seed'] + 32 + seed)
            np.random.seed(config['init_seed'] + 32 + seed)
            # generate single pattern
            frame_id = random.randint(0,31)
            if (config['type_val'] is None):
                type_ = random.randint(1,3)
                f.write(str(type_)+' '+str(frame_id))
                f.write('\n')
            elif (config['type_val'] == 'Concave'):
                type_ = 3
                f.write(str(type_)+' '+str(frame_id))
                f.write('\n')
            else:
                type_ = config['type_val']
                f.write(str(type_)+' '+str(frame_id))
                f.write('\n')
                if (type_ == 3): # python_pattern_type to project_design_type
                    type_ = random.randint(2,3)


            while True:
                dist_list = generate_dist_list(type_)
                if (not config['all_corner'] or ((min(dist_list) == 251 if type_ == 1 else 236) or (min(dist_list) == 1))):
                    break

            stop_gen = stop_generator(type_, dist_list)
            stop_gen_list = list(stop_gen)
            # write input signals
            for bin_array in stop_gen_list:
                for i in range(255):
                    for j in range(16):
                        f.write(str(bin_array[i][j]))
                    f.write('\n')
                f.write('\n')
            f.write('\n')
            stop_sum = reduce(lambda x,y:x+y, stop_gen_list)
            # golden histogram
            for i in range(255):
                for j in range(16-1,0-1,-1):
                    f.write(str(stop_sum[i][j])+' ')
                f.write('\n')
            f.write('\n')
            # golden distance
            for i in range(16-1,0-1,-1):
                f.write(str(dist_list[i])+' ')
            f.write('\n')
            f.write('\n')

if __name__ == '__main__':
    pat_configs_0 = {
        'id_': 0,
        'init_seed': 310551145,
        'starts_with_type_zero': True,
        'total_pattern': 32,
        'type_val': None, # [Concave, 1, 2, 3] Default random
        'all_corner': False
    }

    pat_configs_1 = {
        'id_': 1,
        'init_seed': 19980301,
        'starts_with_type_zero': False,
        'total_pattern': 100,
        'type_val': 1, # [Concave, 1, 2, 3] Default random
        'all_corner': False
    }

    pat_configs_2 = {
        'id_': 2,
        'init_seed': 20220610,
        'starts_with_type_zero': False,
        'total_pattern': 100,
        'type_val': 2, # [Concave, 1, 2, 3] Default random
        'all_corner': False
    }

    pat_configs_3 = {
        'id_': 3,
        'init_seed': 29309010,
        'starts_with_type_zero': False,
        'total_pattern': 100,
        'type_val': 'Concave', # [Concave, 1, 2, 3] Default random
        'all_corner': False
    }

    pat_configs_4 = {
        'id_': 4,
        'init_seed': 89319182,
        'starts_with_type_zero': False,
        'total_pattern': 100,
        'type_val': 3, # [Concave, 1, 2, 3] Default random
        'all_corner': False
    }

    pat_configs_5 = {
        'id_': 5,
        'init_seed': 8964,
        'starts_with_type_zero': True,
        'total_pattern': 132,
        'type_val': 1, # [Concave, 1, 2, 3] Default random
        'all_corner': True
    }

    pat_configs_6 = {
        'id_': 6,
        'init_seed': 31415926,
        'starts_with_type_zero': False,
        'total_pattern': 100,
        'type_val': 3, # [Concave, 1, 2, 3] Default random
        'all_corner': True
    }

    pat_configs_7 = {
        'id_': 7,
        'init_seed': 27182,
        'starts_with_type_zero': True,
        'total_pattern': 132,
        'type_val': None, # [Concave, 1, 2, 3] Default random
        'all_corner': False
    }

    pat_configs_8 = {
        'id_': 8,
        'init_seed': 88888888,
        'starts_with_type_zero': True,
        'total_pattern': 1032,
        'type_val': None, # [Concave, 1, 2, 3] Default random
        'all_corner': False
    }
    
    generate_pattern_file(pat_configs_0)
    generate_pattern_file(pat_configs_1)
    generate_pattern_file(pat_configs_2)
    generate_pattern_file(pat_configs_3)
    generate_pattern_file(pat_configs_4)
    generate_pattern_file(pat_configs_5)
    generate_pattern_file(pat_configs_6)
    generate_pattern_file(pat_configs_7)
    generate_pattern_file(pat_configs_8)