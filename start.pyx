import numpy as np
cimport numpy as np
from libc.stdlib cimport malloc, free
from cython.parallel import parallel, prange
cimport openmp
import cppmap
from cppmap import Memory
include "board.pxi"
include "AI.pxi"

cdef print_shit(board_t *boardc):
    print "number of legal moves: ", boardc.moves_count
    print "Legal moves:"
    for i in xrange(0, boardc.moves_count):
        print boardc.moves[i]



def get_best_move(Board board):
    pass
    
    
cdef play(ai = AI(), nr_games = 1):
    for i in range(nr_games):
        board = Board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - 0 1") 
        turn = 0
                    
        while True:
                if board.have_lost():
                        board.print_board()
                        print "ai lost"
                        ai.punish()
                        break
                else:
                          ai.do_best_move(board)
                    
                board.swapturn()
                
                if board.have_lost():
                        board.print_board()
                        print "ai won"
                        ai.reward()
                        break
                else:
                    lmoves = board.get_all_legal_moves()
                    r = random.randint(0,len(lmoves)-1)
                    board.move(lmoves[r])
                    
                board.swapturn()
                turn += 1
                if turn > 80:
                    break
                
            
def foo():
    cdef int i, j, n
    ai = [AI() for _ in range(10)]
    board = [Board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - 0 1") for _ in range(10)]


    with nogil, parallel():
        for i in prange(5):
            with gil:
               play(ai[i])
                
def test():
    print np.version.version
    board = Board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - 0 1")
    board.print_board()
    board.calculate_legal_moves(0, 6)
    board.print_legal_moves()
    cdef int nr_shits = 5
  #  board.do_move(1,0,0,0)
    board.print_board()
    
    aiw = [AI() for _ in range(2)]
    ite = 0
    aiwon = 0
    randomwon = 0
    while ite < 10000000:
        turn = 0
        board = Board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - 0 1")
        if ite%100 == 0:
            print "iteration: ", ite
            aiw[0].print_nr_wins()            
            aiw[1].print_nr_wins()
            print "random won : ", randomwon
            aiw[0].print_mem_att()
            aiw[1].print_mem_att()
            aiw[0].print_generation()
            aiw[1].print_generation()
            aiw[0].print_AI_att()
            aiw[1].print_AI_att()
            if aiw[0].get_score() > aiw[1].get_score():
                print "0 WON"
                aiw[1].mutate(aiw[0])
            else:
                print "1 WON"
                aiw[0].mutate(aiw[1])
            aiw[0].clear_nr_of_wins()
            aiw[1].clear_nr_of_wins()
            randomwon = 0
        board.swapturn()

        while turn < 50:
            board.swapturn()
            #AI MOVE
            if board.have_lost():
                randomwon += 1
                board.print_board()
                print "aiw lost"
                print turn
                aiw[ite%2].punish()
                break
            #print "turn: "
            #print board.cboard.turn            
            #board.print_board()
            #board.print_legal_moves()
            aiw[ite%2].do_best_move(board)
            
            
            
            board.swapturn()
            #RANDOM MOVE
            if board.have_lost():
                aiwon += 1
                print board.get_all_legal_moves()
                board.print_board()
                aiw[(ite)%2].reward()
                print "--------------------------------- AI WON ----------------------"           
                break    
                                   
            lmoves = board.get_all_legal_moves()
            r = random.randint(0,len(lmoves)-1)
            #print "random move: ", r
            board.move(lmoves[r])
            
            
            turn += 1
        if turn == 50:
            #print "punish both"
            #aiw[ite%2].mutate(aiw[ite%2])            
            aiw[ite%2].punish()
            #print "memory_size: ", aiw[ite%2].print_len_memory()
        ite += 1
    # memory.shits(nr_shits, m.data)  
#    board.calculate_legal_moves(0,7)
#    print board.get_legal_moves()    
#    board.print_legal_moves()
#    print "finding all legal moves"
#    legalmoves = board.get_all_legal_moves()
#    print legalmoves
#    board.print_board()
#    board.move(legalmoves[0])
#    board.print_board()
#    board.reverse_move()
#    board.print_board()
    
    #print board.multiply(tes[2])

#    cdef np.ndarray[np.uint16_t, ndim=2, mode="c"] board = np.zeros((8,8), dtype=np.uint16)
#    cdef coord_t coords
#    cdef board_t cboard
#
#    board.fill(P_EMPTY)
#
#    coords.y = 0
#    coords.x = 6
#
#    board[1][0] = WHITE_PAWN
#    board[0][5] = WHITE_KING
#    board[0][6] = WHITE_ROOK
#    board[0][7] = BLACK_ROOK
#
#    board[6][0] = BLACK_PAWN
#    board[7][0] = BLACK_ROOK
#    board[7][7] = WHITE_PAWN
#    board[4][4] = BLACK_KING
#    
#
#    cboard.board = <piece_t *>board.data
#    cboard.moves_count = 0
#    cboard.turn = WHITE
#
#    #cdef move *moves = <move *>malloc(100 * sizeof(move))
#    #cboard.moves = moves    
#    #print "moves initialized"
#    #print moves[1]
#    
#    print_board(cboard.board)
#    get_legal_moves(&cboard, &coords)
#    print "after get_legal_moves"
#    #print_shit(&cboard)
#    print_shit(&cboard)
