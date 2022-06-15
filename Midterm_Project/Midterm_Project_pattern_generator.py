import random
from tqdm import tqdm
import numpy as np

def generate_single_pattern_value(window_val):
    # window_val = random.randint(0,3)
    # mode_val = mode_val = random.randint(0,1)
    # frame_id_val = frame_id_val
    start_cnt = random.randint(4,255)
    stop_list = [[[random.randint(0,1) for k in range(16)] for j in range(255)] for i in range(start_cnt)]

    stop_arr = np.array(stop_list)
    stop_sum = stop_arr.sum(axis=0)
    stop_cumsum = sum([np.roll(stop_sum,shift=-i,axis=0) for i in range(2**window_val)])[:255-(2**window_val)+1]
    dist = np.argmax(stop_cumsum,axis=0) + 1 # the index of bin starts from 1 rather than 0
    return stop_list, stop_sum, dist

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

def update_DRAM(frame,stop_sum,dist,mode):
    global dram_dict
    if (mode==1):
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
            
    global gold_dict
    for hist_num in range(16):
        for hist_dat in range(0,256,4):
            if (hist_dat!=252):
                dat = ' '.join([hex(stop_sum[hist_dat+i][-1-hist_num]).lstrip('0x').zfill(2).upper() for i in range(4)])
            else: # last index
                dat = ' '.join([hex(stop_sum[hist_dat+i][-1-hist_num]).lstrip('0x').zfill(2).upper() for i in range(3)])
                dat = dat + ' ' + hex(dist[::-1][hist_num]).lstrip('0x').zfill(2).upper()
            # print(dat)
            gold_dict[
                "@" + 
                hex(frame+16).lstrip('0x').zfill(2).upper() + 
                hex(hist_num).lstrip('0x').zfill(1).upper() + 
                hex(hist_dat).lstrip('0x').zfill(2).upper()
            ] = dat

def output_DRAM():
    global dram_dict
    global gold_dict
    with open('dram.dat','w') as dram_f:
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
                    
    with open('golden_dram.dat','w') as dram_f:
        for frame in range(32):
            for hist_num in range(16):
                for hist_dat in range(0,256,4):
                    addr = \
                        "@" + \
                        hex(frame+16).lstrip('0x').zfill(2).upper() + \
                        hex(hist_num).lstrip('0x').zfill(1).upper() + \
                        hex(hist_dat).lstrip('0x').zfill(2).upper()

                    dram_f.write(addr+'\n')
                    dram_f.write(gold_dict[addr]+'\n')

if __name__ == '__main__':
    # Initalize DRAM
    dram_dict = initialize_DRAM()
    gold_dict = initialize_DRAM()

    with open('input.txt','w') as f:
        pat = 32 # pat <= 32
        f.write(str(pat)+'\n')
        f.write('\n')

        random.seed(0)
        frame_id_list = list(range(32))
        random.shuffle(frame_id_list)

        for i in tqdm(range(pat)):
            # generate single pattern
            window_val = random.randint(0,3)
            mode_val = mode_val = random.randint(0,1)
            frame_id_val = frame_id_list[i]
            # print(window_val,mode_val,frame_id_val)
            stop_list, stop_sum, dist = generate_single_pattern_value(window_val)
            start_cnt = len(stop_list)

            # update DRAM information
            update_DRAM(frame_id_val,stop_sum,dist,mode_val)

            # write pattern information
            f.write(' '.join((str(v) for v in (window_val,mode_val,frame_id_val)))+'\n')
            # stop signal
            if (mode_val==0):
                f.write(str(start_cnt)+'\n')
                for i in range(start_cnt):
                    for j in range(255):
                        for k in range(16):
                            f.write(str(stop_list[i][j][k]))
                        f.write('\n')
                    f.write('\n')
                f.write('\n')

    output_DRAM()                    