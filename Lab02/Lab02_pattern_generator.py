import os
import random
import numpy as np
from itertools import permutations

perm_list = list(permutations(range(8),5))
answer_dict = dict()
for i,guess in enumerate(perm_list):
    answer = nanb(guess)
    if answer not in answer_dict:
        answer_dict[answer] = {i}
    else:
        answer_dict[answer].add(i)

def nanb(guess=[0,1,2,3,4],ground_truth=[0,1,2,3,4]):
    length = len(guess)
    for i in range(length):
        for j in range(i+1,length):
            assert guess[i] != guess[j]
    for i in range(length):
        for j in range(i+1,length):
            assert ground_truth[i] != ground_truth[j]
    A = 0
    B = 0
    for i in range(len(guess)):
        if guess[i] == ground_truth[i]:
            A += 1
    for i in range(length):
        for j in range(length):
            if (guess[i] == ground_truth[j] and i!=j):
                B += 1
    return A,B

def solve(key,ans,wei,mat):
    keyboard_arr = key.copy() # sorted numpy.array w 8 elements
    answer_arr = ans.copy() # numpy.array w 5 unique samples from key
    weight_arr = wei.copy() # numpy.array
    match_target = mat # tuple (A,B)
    
    # desort keyboard_arr by answer_arr
    for i in range(5): # desort
        for j in range(i+1,8):
            if (answer_arr[i]==keyboard_arr[j]):
                temp = keyboard_arr[i]
                keyboard_arr[i] = keyboard_arr[j]
                keyboard_arr[j] = temp

    match_perm_ind_list = [perm_list[i] for i in answer_dict[match_target]]
    match_perm_val_list = [[keyboard_arr[j] for j in i] for i in match_perm_ind_list]
    weighted_sum = [sum(np.array(i)*weight_arr) for i in match_perm_val_list]
    weighted_sum_2 = [sum(np.array(i)*np.array([16,8,4,2,1])) for i in match_perm_val_list]
    summary = [(weighted_sum[i],\
                weighted_sum_2[i],\
                -match_perm_val_list[i][0],\
                -match_perm_val_list[i][1],\
                -match_perm_val_list[i][2],\
                -match_perm_val_list[i][3],\
                -match_perm_val_list[i][4]) for i in range(len(match_perm_ind_list))]
    summary.sort(reverse=True)
    seq = (-summary[0][-5],-summary[0][-4],-summary[0][-3],-summary[0][-2],-summary[0][-1])
    ws = summary[0][0]
    return seq, ws, summary

def generate_pattern(input_filename,output_filename,type_,n_pattern=1000,n_seed=2022):
    random.seed(n_seed)
    with open(input_filename,'w') as f:
        f.write(str(n_pattern)+'\n')
        f.write('\n')
    with open(input_filename,'a') as f_in:
        with open(output_filename,'a') as f_out:
            i=0
            while (i<n_pattern):
                keyboard_arr = np.array(random.sample(range(1,32), 8))
                answer_arr = keyboard_arr[:5].copy()
                keyboard_arr.sort()
                weight_arr = np.array(random.sample(range(1,16), 5))
                match_target = random.sample(answer_dict.keys(),1)[0]
                seq, ws, summary = solve(keyboard_arr,answer_arr,weight_arr,match_target)
                
                cond = False
                if type_==0: # no condition
                    cond = True
                elif type_==1: # corner_case_1: weighted_sum
                    if (len(summary)>1 and (summary[0][0] == summary[1][0])):
                        cond = True
                elif type_==2: # corner_case_2:
                    if (len(summary)>1 and (summary[0][:2] == summary[1][:2])):
                        cond = True
                else:
                    raise('Wrong type')
                    
                if (cond):
                    # print(i)
                    i += 1
                else:
                    continue

                f_in.write(' '.join([str(i) for i in keyboard_arr.tolist()])+'\n')
                f_in.write(' '.join([str(i) for i in answer_arr.tolist()])+'\n')
                f_in.write(' '.join([str(i) for i in weight_arr.tolist()])+'\n')
                f_in.write(' '.join([str(i) for i in match_target])+'\n')
                f_in.write('\n')

                f_out.write('\n')
                f_out.write(' '.join([str(i) for i in seq])+'\n')
                f_out.write(str(ws)+'\n')

# generate_pattern('input_0.txt','output_0.txt',type_=0)
# generate_pattern('input_1.txt','output_1.txt',type_=1)
# generate_pattern('input_2.txt','output_2.txt',type_=2)