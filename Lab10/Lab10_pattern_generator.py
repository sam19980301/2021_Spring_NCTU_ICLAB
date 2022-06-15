import numpy as np
np.random.seed(0)

class Data(object):
    def __init__(self,data=None):
        if (data is None):
            self.data = np.random.randint(-64,64,size=(8,8))
            # self.data = np.random.randint(-64,64,size=(8,8))
        else:
            assert np.array(data).shape == (8,8)
            self.data = np.array(data)
            
        self.center = (3,3) # index of upper left block
    
    def get_subregion(self):
        sub_region = self.data[self.center[0]:self.center[0]+2,self.center[1]:self.center[1]+2].copy()
        # print(sub_region)
        return sub_region
        
    def Midpoint(self):
        sub_region = self.get_subregion()
        sub_region = sub_region.reshape(-1)
        sub_region.sort()
        midpoint = int((sub_region[1] + sub_region[2]) / 2) 
        
        self.data[self.center[0]+0,self.center[1]+0] = midpoint
        self.data[self.center[0]+0,self.center[1]+1] = midpoint
        self.data[self.center[0]+1,self.center[1]+0] = midpoint
        self.data[self.center[0]+1,self.center[1]+1] = midpoint
    
    def Average(self):
        sub_region = self.get_subregion().reshape(-1)
        average = int(sum(sub_region) / 4) 
        
        self.data[self.center[0]+0,self.center[1]+0] = average
        self.data[self.center[0]+0,self.center[1]+1] = average
        self.data[self.center[0]+1,self.center[1]+0] = average
        self.data[self.center[0]+1,self.center[1]+1] = average        
    
    def Counterclockwise_Rotation(self):
        sub_region = self.get_subregion()

        self.data[self.center[0]+0,self.center[1]+0] = sub_region[0,1]
        self.data[self.center[0]+0,self.center[1]+1] = sub_region[1,1]
        self.data[self.center[0]+1,self.center[1]+0] = sub_region[0,0]
        self.data[self.center[0]+1,self.center[1]+1] = sub_region[1,0]
    
    def Clockwise_Rotation(self):
        sub_region = self.get_subregion()

        self.data[self.center[0]+0,self.center[1]+0] = sub_region[1,0]
        self.data[self.center[0]+0,self.center[1]+1] = sub_region[0,0]
        self.data[self.center[0]+1,self.center[1]+0] = sub_region[1,1]
        self.data[self.center[0]+1,self.center[1]+1] = sub_region[0,1]
    
    def Flip(self):
        sub_region = self.get_subregion()
        
        self.data[self.center[0]+0,self.center[1]+0] = -sub_region[0,0]
        self.data[self.center[0]+0,self.center[1]+1] = -sub_region[0,1]
        self.data[self.center[0]+1,self.center[1]+0] = -sub_region[1,0]
        self.data[self.center[0]+1,self.center[1]+1] = -sub_region[1,1] 
    
    def Shift_up(self):
        if (self.center[0] > 0):
            self.center = (self.center[0]-1,self.center[1])
    
    def Shift_left(self):
        if (self.center[1] > 0):
            self.center = (self.center[0],self.center[1]-1)
    
    def Shift_down(self):
        if (self.center[0] < 6):
            self.center = (self.center[0]+1,self.center[1])
    
    def Shift_right(self):
        if (self.center[1] < 6):
            self.center = (self.center[0],self.center[1]+1)
    
    def Zoom_in(self):
        output = self.data[
            self.center[0]+1:self.center[0]+5,
            self.center[1]+1:self.center[1]+5
        ].copy()
        assert output.shape == (4,4)
        return output
    
    def Zoom_out(self):
        output = self.data[::2,::2].copy()
        assert output.shape == (4,4)
        return output
    
    def Output(self):
        if ((self.center[0]>=4) or self.center[1]>=4):
            return self.Zoom_out()
        else:
            return self.Zoom_in()
            
    def perform_action(self,action_no=None):
        assert action_no in [0,1,2,3,4,5,6,7,8]
        if (action_no == 0):
            self.Midpoint()
        elif (action_no == 1):
            self.Average()
        elif (action_no == 2):
            self.Counterclockwise_Rotation()
        elif (action_no == 3):
            self.Clockwise_Rotation()
        elif (action_no == 4):
            self.Flip()
        elif (action_no == 5):
            self.Shift_up()
        elif (action_no == 6):
            self.Shift_left()
        elif (action_no == 7):
            self.Shift_down()
        elif (action_no == 8):
            self.Shift_right()

# operation_table = {
#     0: 'Midpoint',
#     1: 'Average',
#     2: 'Counterclockwise_Rotation',
#     3: 'Clockwise_Rotation',
#     4: 'Flip',
#     5: 'Shift_up',
#     6: 'Shift_left',
#     7: 'Shit_down',
#     8: 'Shift_right'
# }

# # Test
# test_data = [
#     [ -26,  28,  30, -12,  24,  -5,   8,   7],
#     [ -19,  22,  -6,  14,  23,  19,  -1, -23],
#     [  -6,  -5,  18,  19,  23,   4,  -8,   3],
#     [  -6,   5,  -3,  -9,   6,   8,   9,  -2],
#     [  12,  11,  18,   5,  11,  -5,  20, -12],
#     [ -15, -18, -30,  20,  31,   1, -19,  -4],
#     [ -25, -16,   9,  30,   1, -31,   1,  25],
#     [   7,  30, -31,  30,  -9,   4,  12,   6]
# ]
# action_list = [0,5,8,8,4]

# data = Data(data=test_data)
# for action in action_list:
#     data.perform_action(action)
# print(data.Output())

# # Test
# test_data = [
#     [ -26,  28,  30, -12,  24,  -5,   8,   7],
#     [ -19,  22,  -6,  14,  23,  19,  -1, -23],
#     [  -6,  -5, -10,  19,  23,  -4,   8,   3],
#     [  -6,   5,  -3,  -9,   6,  -8, -9,  -2],
#     [  12,  11,  18,   5,  11,  -5,  20, -12],
#     [ -15, -18, -30,  20,  31,   1, -19,  -4],
#     [ -25, -16,   9,  30,   1, -31,   1,  25],
#     [   7,  30, -31,  30,  -9,   4,  12,   6]
# ]

# action_list = [5,6,6,1,3,6,6]
# data = Data(data=test_data)
# for action in action_list:
#     data.perform_action(action)
# print(data.Output())

# # DEBUG
# i=16
# np.random.seed(i)
# data = Data()
# action_list = np.random.randint(0,9,size=15)
# print(action_list)
# print(data.center)
# print(data.data)
# print("Start performing actions")

# for action in action_list:
#     data.perform_action(action)
#     print(action)
#     print(data.center)
#     print(data.data)
    
# output_data = data.Output()
# print(output_data)

# Generate pattern

with open('input.txt','w') as f:
    pat = 100
    f.write(str(pat) + '\n')
    f.write('\n')
    
    seed = 0
    i= 0
    while (i<pat):
        np.random.seed(seed)

        data = Data()
        action_list = np.random.randint(0,9,size=15)
        # # corner case
        # data.data[3,3] = -64
        # action_list[0] = 4
        # action_list[1] = 0
        
        orig = data.data.copy()
        for action in action_list:
            data.perform_action(action)
        output_data = data.Output()
        
        if ((output_data.reshape(-1) >= -64).all() and (output_data.reshape(-1) <= 63).all()):
            
            assert (output_data.reshape(-1) >= -64).all() and (output_data.reshape(-1) <= 63).all()
            
            # in_data signal
            f.write(' '.join([str(i) for i in orig.reshape(-1)]) + '\n')
            f.write('\n')

            # op signal
            f.write(' '.join([str(i) for i in action_list]) + '\n')
            f.write('\n')



            # out_data signal
            f.write(' '.join([str(i) for i in output_data.reshape(-1)]) + '\n')
            f.write('\n')

            f.write('\n')
            i += 1
        else:
            print(f"{i} th data is not valid")

        seed += 1