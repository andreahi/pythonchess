# -*- coding: utf-8 -*-
"""
Created on Sun Sep 28 16:15:36 2014

@author: Andreas
"""
import numpy as np
cimport numpy as np
from cppmap import Memory
import itertools
import bisect 

import random
cdef class AI:
    cdef memory
    cdef np.ndarray piecess
    cdef np.ndarray m 
    cdef np.ndarray features 
    cdef int nr_features
    #cdef shortmemory
    cdef int move_nr
    cdef int nr_wins
    cdef int generation
    def __init__(self):
        self.nr_wins = 0
        self.generation = 0
        cdef int nr_features= 20
        piecesl = [WHITE_PAWN,
           WHITE_KNIGHT,
           WHITE_BISHOP,
           WHITE_ROOK,
           WHITE_QUEEN,
           WHITE_KING,
           BLACK_PAWN,
           BLACK_KNIGHT,
           BLACK_BISHOP,
           BLACK_ROOK,
           BLACK_QUEEN,
           BLACK_KING,
           4096]
        
        cdef np.ndarray[np.uint16_t, ndim=1, mode="c"] piecess =np.array(range(4096,8191+1), dtype=np.uint16)
        cdef np.ndarray[np.int32_t, ndim=1, mode="c"] m = np.zeros((nr_features), dtype=np.int32)
        cdef np.ndarray[np.uint16_t, ndim=3, mode="c"] features =   np.bitwise_or(np.bitwise_or(np.random.choice(piecess, (nr_features,8,8)).view('uint16') ,
                                                                                np.random.choice(piecess, (nr_features,8,8)).view('uint16')),
                                                                                np.bitwise_or(np.random.choice(piecess, (nr_features,8,8)).view('uint16') ,
                                                                                np.random.choice(piecess, (nr_features,8,8)).view('uint16')))

        self.memory = Memory()
        self.piecess = piecess
        self.m = m
        self.features = features
        self.nr_features = nr_features
        self.move_nr = 0
       # self.shortmemory = Memory()
    cdef _get_best_move(self, Board board, legal_moves):
        scores = []
        
        for e in legal_moves:
            board.move(e)
            for i in range(self.nr_features):        
                self.m[i] = board.multiply(self.features[i])
                #self.m[i] = random.randint(0,1)
               # if self.m[i]:
                #    print "non-zero feature : ", i
            #print "mem: ", self.m
            scores.append(self.memory.lookup(self.m, self.nr_features)+.001)
            board.reverse_move()
        choices = range(0,len(scores)) 
        weights = scores
        cumdist = []
        count = 0
        for e in scores:
            count += e
            cumdist.append(count)
        x = random.random() * cumdist[-1]
        #print choices
        #print weights     
        #print "my choice: ",  choices[bisect.bisect(cumdist, x)]
        return choices[bisect.bisect(cumdist, x)]
            #print "random choise"            
            #print choices[bisect.bisect(cumdist, x)]
                
        #return  np.argmax(scores)     
        
    cpdef do_best_move(self, Board board):        
        legal_moves = board.get_all_legal_moves()
        cdef int best_move = self._get_best_move(board,legal_moves)
        board.move(legal_moves[best_move])
        for i in range(self.nr_features):        
                self.m[i] = board.multiply(self.features[i])
        self.memory.rememberaction(self.m, self.nr_features)
        return legal_moves[best_move] 

    # EVERYTHING YOU DO IS WRONG    
    cpdef punish(self):
        self.memory.weaken_axons()
       
        
    cpdef reward(self):
        self.nr_wins += 1
        self.memory.strengthen_axons()
    
    cpdef mutate(self, AI ai):
        self.features = np.copy(ai.features)
        self.features[random.randint(0,self.nr_features-1)][random.randint(0,8-1)][random.randint(0,8-1)] = random.randint(4096,8191+1) | random.randint(4096,8191+1) | random.randint(4096,8191+1)| random.randint(4096,8191+1)
        self.generation += 1
        self.memory.set_lr(ai.memory.get_lr_punish(), ai.memory.get_lr_reward())
        self.memory.mutate()

    cpdef print_len_memory(self):
        print "print len memory: "        
        self.memory.print_len_memory()
        
    cpdef print_generation(self):
        print "generation: ", self.generation        
    cpdef print_nr_wins(self):
        print "nr_wins: ", self.nr_wins
    cpdef get_nr_of_wins(self):
        return self.nr_wins
        
    cpdef clear_nr_of_wins(self):
        self.nr_wins = 0
    
    cpdef print_mem_att(self):
        print "memory attributes : "
        self.print_len_memory()
        self.memory.print_att()            