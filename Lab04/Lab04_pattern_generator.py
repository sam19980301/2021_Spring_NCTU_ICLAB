import numpy as np
import torch
import random
from torch import nn

# https://github.com/KarenUllrich/pytorch-binary-converter
from pytorch_binary_converter import binary_converter 

torch.manual_seed(0)
random.seed(0)
img_range = 5 # [-100,100)
ker_range = 5 # [-10,10)

def generate_input(seed,img_range,ker_range):
    torch.manual_seed(seed)
    random.seed(seed)
    image_1 = (torch.rand((1,1,4,4)) - 0.5) * img_range # (batch_size, channel, height, width)
    image_2 = (torch.rand((1,1,4,4)) - 0.5) * img_range
    image_3 = (torch.rand((1,1,4,4)) - 0.5) * img_range
    image_list = [image_1, image_2, image_3]

    kernel_1 = (torch.rand((4,1,3,3)) - 0.5) * ker_range # (out, in, height, width)
    kernel_2 = (torch.rand((4,1,3,3)) - 0.5) * ker_range
    kernel_3 = (torch.rand((4,1,3,3)) - 0.5) * ker_range
    kernel_list = [kernel_1, kernel_2, kernel_3]

    opt = random.randint(0,3)
    return image_list, kernel_list, opt

def single_foward(input_value,ker_weight,opt):
    conv_layer = nn.Conv2d(in_channels=1,out_channels=4,kernel_size=(3,3)) # (batch_size, channel, height, width)
    conv_layer.weight = nn.Parameter(ker_weight)
    conv_layer.bias = nn.Parameter(torch.tensor([0.0,0.0,0.0,0.0]))
    padding_layer = nn.ZeroPad2d(1) if ((opt==2) or (opt==3)) else nn.ReplicationPad2d(1)
    
    x = input_value
    x = padding_layer(x)
    x = conv_layer(x)
    return x

def forward(image_list,kernel_list,opt):
    if (opt==0):
        actv_layer = nn.ReLU()
    elif (opt==1):
        actv_layer = nn.LeakyReLU(negative_slope=0.1)
    elif (opt==2):
        actv_layer = nn.Sigmoid()
    else:
        actv_layer = nn.Tanh()

    y1 = single_foward(image_list[0],kernel_list[0],opt)
    y2 = single_foward(image_list[1],kernel_list[1],opt)
    y3 = single_foward(image_list[2],kernel_list[2],opt)
    y = (y1 + y2 + y3)
    y = actv_layer(y)
    return y[0]

def reshuffle(x):
    shuffle_ans = \
    torch.tensor([
    x[0][0][0],
    x[1][0][0],
    x[0][0][1],
    x[1][0][1],
    x[0][0][2],
    x[1][0][2],
    x[0][0][3],
    x[1][0][3],

    x[2][0][0],
    x[3][0][0],
    x[2][0][1],
    x[3][0][1],
    x[2][0][2],
    x[3][0][2],
    x[2][0][3],
    x[3][0][3],

    x[0][1][0],
    x[1][1][0],
    x[0][1][1],
    x[1][1][1],
    x[0][1][2],
    x[1][1][2],
    x[0][1][3],
    x[1][1][3],

    x[2][1][0],
    x[3][1][0],
    x[2][1][1],
    x[3][1][1],
    x[2][1][2],
    x[3][1][2],
    x[2][1][3],
    x[3][1][3],

    x[0][2][0],
    x[1][2][0],
    x[0][2][1],
    x[1][2][1],
    x[0][2][2],
    x[1][2][2],
    x[0][2][3],
    x[1][2][3],

    x[2][2][0],
    x[3][2][0],
    x[2][2][1],
    x[3][2][1],
    x[2][2][2],
    x[3][2][2],
    x[2][2][3],
    x[3][2][3],

    x[0][3][0],
    x[1][3][0],
    x[0][3][1],
    x[1][3][1],
    x[0][3][2],
    x[1][3][2],
    x[0][3][3],
    x[1][3][3],

    x[2][3][0],
    x[3][3][0],
    x[2][3][1],
    x[3][3][1],
    x[2][3][2],
    x[3][3][2],
    x[2][3][3],
    x[3][3][3]
    ])
    return shuffle_ans

bin_opt_dict = {0:'00',1:'01',2:'10',3:'11'}

with open('input.txt','w') as f:
    pat = 500
    f.write(str(pat)+'\n')
    f.write('\n')
    for seed in range(pat):
        img_list, ker_list, opt = generate_input(seed,img_range,ker_range)
        output = forward(img_list,ker_list,opt)
        output = reshuffle(output)
        items_list = [img_list,ker_list]     
        f.write(bin_opt_dict[opt]+'\n')
        f.write('\n')
        for items in items_list:
            for item in items:
                bin_list = [''.join(str(int(i)) for i in arr) for arr in binary_converter.float2bit(item.reshape(-1)).detach().numpy()]
                float_list = [str(i) for i in item.reshape(-1).detach().numpy()]
                for val in bin_list: # float_list:
                    f.write(val+'\n')
                f.write('\n')
        for i in range(64):
            if (output[i] == 0):
                f.write(32*'0'+'\n')
            else:
                f.write(''.join([str(int(i)) for i in binary_converter.float2bit(output[i:i+1]).reshape(-1).detach().numpy()])+'\n')
        f.write('\n')