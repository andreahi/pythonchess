# distutils: language = c++
from libcpp.string cimport string
from libcpp.map cimport map
from libcpp.vector cimport vector
import numpy as np
cimport numpy as np
import random
cdef class Memory:
    cdef map[vector[int], float] mymap
    cdef vector[vector[int]] shortmemory
    cdef float lr_punish
    cdef float lr_reward
    def __init__(self):     
         cdef map[vector[int], float] mymap
         self.mymap = mymap
         cdef vector[vector[int]] shortmemory
         self.shortmemory = shortmemory
         self.lr_punish = 0.1
         self.lr_reward = 1.0
         
    cpdef float lookup(self, np.ndarray[int, ndim=1, mode="c"] key, int length):
        cpdef int* array = <int*>key.data        
        cdef vector[int] output_vector
        output_vector.reserve(length)
        output_vector.assign(array, array + length)
        return self.mymap[output_vector]
    
    cpdef float rememberaction(self, np.ndarray[int, ndim=1, mode="c"] key, int length):
        cpdef int* array = <int*>key.data        
        cdef vector[int] output_vector
        output_vector.reserve(length)
        output_vector.assign(array, array + length)
        self.shortmemory.push_back(output_vector)
        

    cdef float reward_func(self, float prew):
        return min(prew * (1 - self.lr_reward) +  1 * (self.lr_reward), 1)
    
    cdef float punish_func(self, float prew):
        return max(prew * (1 - self.lr_punish) -  1 * (self.lr_punish), 0)
        
    cpdef string strengthen_axons(self):
  
        while self.shortmemory.empty() == False:    
            mem = self.shortmemory.back()    
            self.shortmemory.pop_back()
            self.mymap[mem] = self.reward_func(self.mymap[mem])
    
    cpdef string weaken_axons(self):
        
    
        while self.shortmemory.empty() == False:
            mem = self.shortmemory.back()
            #print mem
            self.shortmemory.pop_back()
            self.mymap[mem] = self.punish_func(self.mymap[mem])
    cpdef set_lr(self, lr_p, lr_r):
        self.lr_punish = lr_p
        self.lr_reward = lr_r
    cpdef get_lr_punish(self):
        return self.lr_punish
    cpdef get_lr_reward(self):
        return self.lr_reward
        
    cpdef print_len_memory(self):
        print self.mymap.size()
    cpdef print_att(self):
        print "P and R : "
        print self.lr_punish
        print self.lr_reward
          
    cpdef mutate(self):
        self.lr_punish *= 1 + random.randint(-1,1)/100.0
        self.lr_reward *= 1 + random.randint(-1,1)/100.0