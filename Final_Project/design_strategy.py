import numpy as np
from functools import reduce

# Design Strategy
def random_independent_strategy(dist_list, stop_gen):
    stop_sum = reduce(lambda x,y:x+y, stop_gen)
    stop_cumsum = sum(
        [
            np.roll(stop_sum,shift=-0,axis=0),
            np.roll(stop_sum,shift=-2,axis=0),
            np.roll(stop_sum,shift=-4,axis=0)
        ]
    )[:-5]
    pred = (np.argmax(stop_cumsum,axis=0)) + 1
    return pred

def group_strategy(dist_list, stop_gen):
    stop_sum = reduce(lambda x,y:x+y, stop_gen)
    stop_cumsum = sum(
        [
            np.roll(stop_sum,shift=-0,axis=0),
            np.roll(stop_sum,shift=-2,axis=0),
            np.roll(stop_sum,shift=-4,axis=0)
        ]
    )[:-5]
    stop_cumsum = np.array([
        stop_cumsum[:,[ 0, 1 ,4, 5]].sum(axis=1),
        stop_cumsum[:,[ 2, 3, 6, 7]].sum(axis=1),
        stop_cumsum[:,[ 8, 9,12,13]].sum(axis=1),
        stop_cumsum[:,[10,11,14,15]].sum(axis=1)
    ]).T
    pred = (np.argmax(stop_cumsum,axis=0)) + 1
    pred = np.array([
        pred[0], pred[0], pred[1], pred[1], 
        pred[0], pred[0], pred[1], pred[1], 
        pred[2], pred[2], pred[3], pred[3], 
        pred[2], pred[2], pred[3], pred[3]
    ])
    return pred

def convex_strategy(dist_list, stop_gen):
    stop_sum = reduce(lambda x,y:x+y, stop_gen)
    stop_cumsum = sum(
        [
            (0+1)*np.roll(stop_sum,shift=-0,axis=0),
            (0+4)*np.roll(stop_sum,shift=-1,axis=0),
            (0+3)*np.roll(stop_sum,shift=-2,axis=0),
            (0+2)*np.roll(stop_sum,shift=-3,axis=0),
            (0+1)*np.roll(stop_sum,shift=-4,axis=0)
        ]
    )[:-5]
    
    center_max_cumsum_list = list()
    center_ind_cumsum_list = list()
    for pred_center in range(16):
        offsets = np.array([max(abs(pred_center//4 - i//4), abs(pred_center%4 - i%4)) for i in range(16)])
        test_stop_cumsum = stop_cumsum.copy()
        test_stop_cumsum[:,offsets==1] = np.roll(test_stop_cumsum[:,offsets==1], shift=- 5, axis=0)
        test_stop_cumsum[:,offsets==2] = np.roll(test_stop_cumsum[:,offsets==2], shift=-10, axis=0)
        test_stop_cumsum[:,offsets==3] = np.roll(test_stop_cumsum[:,offsets==3], shift=-15, axis=0)
        test_stop_cumsum = test_stop_cumsum[:-15+1]
        test_stop_cumsum = test_stop_cumsum.sum(axis=1)
        center_max_cumsum_list.append(test_stop_cumsum.max())
        center_ind_cumsum_list.append(np.argmax(test_stop_cumsum))
    center_max_cumsum_list = np.array(center_max_cumsum_list)
    center_ind_cumsum_list = np.array(center_ind_cumsum_list)
    pred_center = np.argmax(center_max_cumsum_list)
    pred_center_dist = center_ind_cumsum_list[pred_center] + 1
    offsets = np.array([max(abs(pred_center//4 - i//4), abs(pred_center%4 - i%4)) for i in range(16)])
    pred = pred_center_dist + 5 * offsets
    return pred

def concave_strategy(dist_list, stop_gen):
    stop_sum = reduce(lambda x,y:x+y, stop_gen)
    stop_cumsum = sum(
        [
            (0+1)*np.roll(stop_sum,shift=-0,axis=0),
            (0+4)*np.roll(stop_sum,shift=-1,axis=0),
            (0+3)*np.roll(stop_sum,shift=-2,axis=0),
            (0+2)*np.roll(stop_sum,shift=-3,axis=0),
            (0+1)*np.roll(stop_sum,shift=-4,axis=0)
        ]
    )[:-5]
    
    center_max_cumsum_list = list()
    center_ind_cumsum_list = list()
    for pred_center in range(16):
        offsets = np.array([max(abs(pred_center//4 - i//4), abs(pred_center%4 - i%4)) for i in range(16)])
        test_stop_cumsum = stop_cumsum.copy()
        test_stop_cumsum[:,offsets==1] = np.roll(test_stop_cumsum[:,offsets==1], shift= 5, axis=0)
        test_stop_cumsum[:,offsets==2] = np.roll(test_stop_cumsum[:,offsets==2], shift=10, axis=0)
        test_stop_cumsum[:,offsets==3] = np.roll(test_stop_cumsum[:,offsets==3], shift=15, axis=0)
        if (offsets == 3).any():
            test_stop_cumsum[:15] = -1
        else:
            test_stop_cumsum[:10] = -1
        test_stop_cumsum = test_stop_cumsum.sum(axis=1)
        center_max_cumsum_list.append(test_stop_cumsum.max())
        center_ind_cumsum_list.append(np.argmax(test_stop_cumsum))
    center_max_cumsum_list = np.array(center_max_cumsum_list)
    center_ind_cumsum_list = np.array(center_ind_cumsum_list)
    pred_center = np.argmax(center_max_cumsum_list)
    pred_center_dist = center_ind_cumsum_list[pred_center] + 1
    offsets = np.array([max(abs(pred_center//4 - i//4), abs(pred_center%4 - i%4)) for i in range(16)])
    pred = pred_center_dist - 5 * offsets
    return pred

def random_spatialshape_strategy(dist_list, stop_gen):
    stop_sum = reduce(lambda x,y:x+y, stop_gen)
    stop_cumsum = sum(
        [
            (0+1)*np.roll(stop_sum,shift=-0,axis=0),
            (0+4)*np.roll(stop_sum,shift=-1,axis=0),
            (0+3)*np.roll(stop_sum,shift=-2,axis=0),
            (0+2)*np.roll(stop_sum,shift=-3,axis=0),
            (0+1)*np.roll(stop_sum,shift=-4,axis=0)
        ]
    )[:-5]
    
    center_max_cumsum_list = list()
    center_ind_cumsum_list = list()
    for pred_center in range(16):
        offsets = np.array([max(abs(pred_center//4 - i//4), abs(pred_center%4 - i%4)) for i in range(16)])
        test_stop_cumsum = stop_cumsum.copy()
        test_stop_cumsum[:,offsets==1] = np.roll(test_stop_cumsum[:,offsets==1], shift=- 5, axis=0)
        test_stop_cumsum[:,offsets==2] = np.roll(test_stop_cumsum[:,offsets==2], shift=-10, axis=0)
        test_stop_cumsum[:,offsets==3] = np.roll(test_stop_cumsum[:,offsets==3], shift=-15, axis=0)
        test_stop_cumsum = test_stop_cumsum[:-15+1]
        test_stop_cumsum = test_stop_cumsum.sum(axis=1)
        center_max_cumsum_list.append(test_stop_cumsum.max())
        center_ind_cumsum_list.append(np.argmax(test_stop_cumsum))
    center_max_cumsum_list = np.array(center_max_cumsum_list)
    center_ind_cumsum_list = np.array(center_ind_cumsum_list)
    convex_max_cumsum = max(center_max_cumsum_list)
    convex_pred_center = np.argmax(center_max_cumsum_list)
    convex_pred_center_dist = center_ind_cumsum_list[convex_pred_center] + 1

    center_max_cumsum_list = list()
    center_ind_cumsum_list = list()
    for pred_center in range(16):
        offsets = np.array([max(abs(pred_center//4 - i//4), abs(pred_center%4 - i%4)) for i in range(16)])
        test_stop_cumsum = stop_cumsum.copy()
        test_stop_cumsum[:,offsets==1] = np.roll(test_stop_cumsum[:,offsets==1], shift= 5, axis=0)
        test_stop_cumsum[:,offsets==2] = np.roll(test_stop_cumsum[:,offsets==2], shift=10, axis=0)
        test_stop_cumsum[:,offsets==3] = np.roll(test_stop_cumsum[:,offsets==3], shift=15, axis=0)
        if (offsets == 3).any():
            test_stop_cumsum[:15] = -1
        else:
            test_stop_cumsum[:10] = -1
        test_stop_cumsum = test_stop_cumsum.sum(axis=1)
        center_max_cumsum_list.append(test_stop_cumsum.max())
        center_ind_cumsum_list.append(np.argmax(test_stop_cumsum))
    center_max_cumsum_list = np.array(center_max_cumsum_list)
    center_ind_cumsum_list = np.array(center_ind_cumsum_list)
    concave_max_cumsum = max(center_max_cumsum_list)
    concave_pred_center = np.argmax(center_max_cumsum_list)
    concave_pred_center_dist = center_ind_cumsum_list[concave_pred_center] + 1

    
    if (convex_max_cumsum >= concave_max_cumsum): # golden -->  type_ == 2
        pred_center = convex_pred_center
        pred_center_dist = convex_pred_center_dist
        offsets = np.array([max(abs(pred_center//4 - i//4), abs(pred_center%4 - i%4)) for i in range(16)])
        pred = pred_center_dist + 5 * offsets
    else:
        pred_center = concave_pred_center
        pred_center_dist = concave_pred_center_dist
        offsets = np.array([max(abs(pred_center//4 - i//4), abs(pred_center%4 - i%4)) for i in range(16)])
        pred = pred_center_dist - 5 * offsets
    return pred

if __name__ == '__main__':
    PAT = 500
    CORNER_CASE = 1 # 0

    # 1: Random
    cnt = 0
    err = 0
    for i in tqdm(range(PAT)):
        random.seed(i)
        np.random.seed(i)
        type_ = 0
        dist_list = generate_dist_list(type_)
        stop_gen = stop_generator(type_, dist_list)
        pred = random_independent_strategy(dist_list, stop_gen)
        cnt += sum(abs(np.array(dist_list) - pred) <= 3)
        err += sum(abs((dist_list - pred)))
    print("Random Coorelation Result")
    print(f"{cnt} / {PAT * 16}. Accuracy: {cnt / (PAT * 16)}")
    print(f"Total Error {err}, Average {err / (PAT * 16 - cnt)}")

    # 2: Group
    cnt = 0
    err = 0
    for i in tqdm(range(PAT)):
        random.seed(i)
        np.random.seed(i)
        type_ = 1
        dist_list = generate_dist_list(type_)
        stop_gen = stop_generator(type_, dist_list)
        pred = group_strategy(dist_list, stop_gen)
        cnt += sum(abs(np.array(dist_list) - pred) <= 3)
        err += sum(abs((dist_list - pred)))
    print("Group Coorelation Result")
    print(f"{cnt} / {PAT * 16}. Accuracy: {cnt / (PAT * 16)}")
    print(f"Total Error {err}, Average {err / (PAT * 16 - cnt)}")

    # 3: Convex
    cnt = 0
    err = 0
    for i in tqdm(range(PAT)):
        random.seed(i)
        np.random.seed(i)
        type_ = 2
        dist_list, center = generate_dist_list(type_,return_center=True)
        # Corner case
        while CORNER_CASE:
            dist_list, center = generate_dist_list(type_,return_center=True)
            if (min(dist_list) == 236 or min(dist_list) == 1):
                break
        stop_gen = stop_generator(type_, dist_list)
        pred = convex_strategy(dist_list, stop_gen)
        cnt += sum(abs(np.array(dist_list) - pred) <= 3)
        err += sum(abs((dist_list - pred)))
    print("Convex Coorelation Result")
    print(f"{cnt} / {PAT * 16}. Accuracy: {cnt / (PAT * 16)}")
    print(f"Total Error {err}, Average {err / (PAT * 16 - cnt)}")

    # 4: Concave
    cnt = 0
    err = 0
    for i in tqdm(range(PAT)):
        random.seed(i)
        np.random.seed(i)
        type_ = 3
        dist_list, center = generate_dist_list(type_,return_center=True)
        # Corner case
        while CORNER_CASE:
            dist_list, center = generate_dist_list(type_,return_center=True)
            if (min(dist_list) == 236 or min(dist_list) == 1):
                break
        stop_gen = stop_generator(type_, dist_list)
        pred = concave_strategy(dist_list, stop_gen)
        cnt += sum(abs(np.array(dist_list) - pred) <= 3)
        err += sum(abs((dist_list - pred)))
    print("Concave Coorelation Result")
    print(f"{cnt} / {PAT * 16}. Accuracy: {cnt / (PAT * 16)}")
    print(f"Total Error {err}, Average {err / (PAT * 16 - cnt)}")

    # 5: Random Convex/ Concave
    cnt = 0
    err = 0
    for i in tqdm(range(PAT)):
        random.seed(i)
        np.random.seed(i)
        type_ = random.randint(2,3)
        dist_list, center = generate_dist_list(type_,return_center=True)
        # Corner case
        while CORNER_CASE:
            dist_list, center = generate_dist_list(type_,return_center=True)
            if (min(dist_list) == 236 or min(dist_list) == 1):
                break
        stop_gen = stop_generator(type_, dist_list)
        pred = random_spatialshape_strategy(dist_list, stop_gen)
        # assert (abs(pred - dist_list) <= 3).all()
        cnt += sum(abs(np.array(dist_list) - pred) <= 3)
        err += sum(abs((dist_list - pred)))
    print("Random Convex / Concave Coorelation Result")
    print(f"{cnt} / {PAT * 16}. Accuracy: {cnt / (PAT * 16)}")
    print(f"Total Error {err}, Average {err / (PAT * 16 - cnt)}")
