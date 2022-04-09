import numpy as np
import torch
import random
from torch import nn
from torchvision import transforms
from tqdm import tqdm

shape_list = [4,8,16]

# 0
def cross_correlation(img,temp):
    conv_layer = nn.Conv2d(in_channels=1,out_channels=1,kernel_size=(3,3))
    conv_layer.weight = nn.Parameter(temp)
    conv_layer.bias = nn.Parameter(torch.tensor([0.]))
    padding_layer = nn.ZeroPad2d(1)
    
    x = img
    x = padding_layer(x)
    x = conv_layer(x)
    return x

# 1
def max_pooling(img):
    if (img.shape[2:] == (4,4)):
        return img
    # assert (img.shape[2:] == (8,8)) or (img.shape[2:] == (16,16))
    return nn.MaxPool2d(kernel_size=2)(img)

# 2
def horizontal_flip(img):
    return torch.flip(img,(3,))

# 3
def vertical_flip(img):
    return torch.flip(img,(2,))

# 4
def left_diagonal_flip(img):
    x = img
    x = horizontal_flip(x)
    x = torch.transpose(x, 2, 3)
    x = horizontal_flip(x)
    return x

# 5
def right_diagonal_flip(img):
    return torch.transpose(img, 2, 3)

# 6
def zoom_in(img):
    if (img.shape[2:] == (16,16)):
        return img
    # assert (img.shape[2:] == (4,4)) or (img.shape[2:] == (8,8))
    y = torch.zeros(1,1,img.shape[2]*2,img.shape[2]*2)
    y[0][0][::2,::2] = img
    y[0][0][::2,1::2] = torch.trunc(img/3)
    y[0][0][1::2,::2] = torch.trunc((img*2/3))+20
    y[0][0][1::2,1::2] = torch.trunc((img > 0) * (img/2) + (img < 0) * ((img-1)/2))
    return y

# 7
def shortcut_brightness_adjustment(img):
    # assert (img.shape[2:] == (8,8)) or (img.shape[2:] == (16,16))
    x = img
    # x = transforms.CenterCrop(4)(x)
    x = transforms.CenterCrop(max(4,x.shape[2]/2))(x)
    x = torch.trunc((x > 0) * (x/2) + (x < 0) * ((x-1)/2)) + 50
    return x

function_dict = {
    0: cross_correlation,
    1: max_pooling,
    2: horizontal_flip,
    3: vertical_flip,
    4: left_diagonal_flip,
    5: right_diagonal_flip,
    6: zoom_in,
    7: shortcut_brightness_adjustment
}

# image = torch.tensor([[[
#     [-60,-39,-54,-8],
#     [94,-19,87,15],
#     [89,-38,-28,-8],
#     [-4,-54,3,2]
# ]]])

# image = torch.tensor([[[
#     [4,7,-3,-5],
#     [3,-9,9,5],
#     [8,7,6,-1],
#     [8,6,8,-5]
# ]]])

with open('input.txt','w') as f:
    pat = 10000
    f.write(str(pat)+'\n')
    f.write('\n')
    for seed in tqdm(range(pat)):
        torch.manual_seed(20220403+seed)
        random.seed(20220403+seed)
        template = torch.randint(-(2**10),2**5,size=(1,1,3,3)).type(torch.float32) # TBD should be 2**15
        input_shape = random.sample(shape_list,1)[0]
        # print(input_shape)
        # input_shape = 4
        # input_shape = 8
        # input_shape = 16
        image = torch.randint(-(2**5),2**5,size=(1,1,input_shape,input_shape)).type(torch.float32)

        total_instr = random.randint(1,16)
        # total_instr = 4
        # total_instr = 2

        curr_instr = 0
        curr_shape = input_shape
        curr_img = image
        instr_list = list()
        
        # print(curr_img)
        while (curr_instr < total_instr-1):
            instr_num = random.randint(1,7)
            # instr_num = 7
            # instr_num = random.sample(instr_dict[curr_shape],1)[0]
            instr_list.append(instr_num)
            curr_img = function_dict[instr_num](curr_img)
            curr_shape = curr_img.shape[2]
            curr_instr += 1
            # print(instr_num)
            # print(curr_img)

        instr_list.append(0)
        curr_img = function_dict[0](curr_img,template)
        curr_shape = curr_img.shape[2]
        curr_instr += 1
        # print(0)
        # print(curr_img)
        # print(len(instr_list),instr_list)

        # 1. image size
        # 2. image data
        # 3. template data
        # 4. action length
        # 5. action list
        # 6. result size
        # 7. result value
        # 8. result max position
        # 9. matching template position
        
        # image size
        f.write(str(input_shape)+'\n')
        f.write('\n')
        
        # image data
        for val in image.reshape(-1).type(torch.int64).detach().numpy():
            f.write(str(val)+' ')
        f.write('\n')
        
        # template data
        for val in template.reshape(-1).type(torch.int64).detach().numpy():
            f.write(str(val)+' ')
        f.write('\n')
        
        # action length
        f.write(str(len(instr_list)))
        f.write('\n')
        
        # action list
        for val in instr_list:
            f.write(str(val)+' ')
        f.write('\n')
        
        # result shape
        f.write(str(curr_shape))
        f.write('\n')
        
        # result value
        for val in curr_img.reshape(-1).type(torch.int64).detach().numpy():
            f.write(str(val)+' ')
        f.write('\n')
        
        # position of maximum value
        v = np.argmax(curr_img.reshape(-1).detach().numpy())
        x = v//curr_shape
        y = v%curr_shape
        f.write(str(x)+' ')
        f.write(str(y)+' ')
        f.write('\n')
        
        # matching template position (length and value list)
        top_valid = not (x==0)
        bot_valid = not (x==curr_shape-1)
        left_valid = not (y==0)
        right_valid = not (y==curr_shape-1)
        
        pos_list = list()
        
        if (left_valid and top_valid):
            pos_list.append((x-1)*curr_shape+(y-1))
        if (top_valid):
            pos_list.append((x-1)*curr_shape+(y+0))
        if (right_valid and top_valid):
            pos_list.append((x-1)*curr_shape+(y+1))

        if (left_valid):
            pos_list.append((x)*curr_shape+(y-1))
        pos_list.append((x)*curr_shape+(y+0))
        if (right_valid):
            pos_list.append((x)*curr_shape+(y+1))

        if (left_valid and bot_valid):
            pos_list.append((x+1)*curr_shape+(y-1))
        if (bot_valid):
            pos_list.append((x+1)*curr_shape+(y+0))
        if (right_valid and bot_valid):
            pos_list.append((x+1)*curr_shape+(y+1))
        
        f.write(str(len(pos_list)))
        f.write('\n')

        for val in pos_list:
            f.write(str(val)+' ')
        f.write('\n')