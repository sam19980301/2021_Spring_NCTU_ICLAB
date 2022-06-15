import random

def generate_pattern(val_range,suffix=None):
    random.seed(0)
    
    # random input signals
    account_arr = [random.randint(0,255) for i in range(4000)]
    area_arr = [random.randint(1,val_range) for i in range(4000)] # 255 or 5
    latency_arr = [random.randint(1,val_range) for i in range(4000)]
    
    
    performance_arr = [tup[0]*tup[1] for tup in zip(area_arr,latency_arr)]
    
    # calculate answer
    acc_result_list = list()
    for ind in range(0+5-1,4000):
        acc_result = 0
        performance = 255*255 + 1
        for i in range(5):
            if (performance_arr[ind - i] < performance):
                acc_result = ind - i
                performance = performance_arr[ind - i]
        acc_result_list.append(acc_result)
    acc_result_list = [account_arr[ind] for ind in acc_result_list]

    with open(f"input{'' if suffix is None else '_' + suffix}.txt",'w') as f:
        f.write(' '.join([str(i) for i in account_arr]))
        f.write('\n')

        f.write(' '.join([str(i) for i in area_arr]))
        f.write('\n')

        f.write(' '.join([str(i) for i in latency_arr]))
        f.write('\n')

        f.write(' '.join([str(i) for i in acc_result_list]))

generate_pattern(255)
generate_pattern(5,'small') # used for check same-performance-corner-case