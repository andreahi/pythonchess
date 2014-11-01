#include "smmintrin.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include "common.h"
#include "AI.h"

#define MAGIC_LENGTH 6
static unsigned char ai_mem_magic[] = "\x01\x02\x03\x04\x05\x06";

AI_instance_t *ai_new(int mutation_rate)
{
    int i,j;
    AI_instance_t *ret;

    ret = calloc(1, sizeof(struct AI_instance));
    if (ret == NULL) {
        perror("malloc");
        return NULL;
    }

    ret->nr_ports = 128;
    ret->board_size = 64*2*2*8;
    ret->nr_synapsis = ret->nr_ports + ret->board_size;
    ret->nr_brain_parts = 3;    

    ret->brain = (int ***)malloc_3d(ret->nr_synapsis / (sizeof(int) * 8),
            ret->nr_ports,  ret->nr_brain_parts, sizeof(int));

    for(j = 0; j < ret->nr_brain_parts; j++){
        for(i = 0; i < ret->nr_synapsis * ret->nr_ports; i++)

                if(!random_int_r(0, 100000))
                    SetBit(&ret->brain[j][0][0], i);
                else
                    ClearBit(&ret->brain[j][0][0], i);

    }

    ret->move_nr = 0;
    ret->nr_wins = ret->nr_losses = ret->nr_games_played = 0;
    ret->generation = 0;
    ret->mutation_rate = mutation_rate;

    return ret;
}

AI_instance_t *copy_ai(AI_instance_t *ai)
{
    AI_instance_t *ret = calloc(1, sizeof(AI_instance_t));

    memcpy(ret, ai, sizeof(AI_instance_t));
    ret->brain = (int ***)memdup_3d((void ***)ai->brain);

    clear_score(ret);
    return ret;
}

int dump_ai(char *file, AI_instance_t *ai)
{
    FILE *out;
    long brain_size = (ai->nr_synapsis/(sizeof(int) * 8)) *
        ai->nr_ports * sizeof(int)*ai->nr_brain_parts;

    out = fopen(file, "w");
    if (out == NULL)
        return 0;

    fwrite(ai_mem_magic, 1, MAGIC_LENGTH, out);
    fwrite(ai, 1, sizeof(AI_instance_t), out);
    
    fwrite(&ai->brain[0][0][0], 1, brain_size, out);
    
    fclose(out);

    return 1;
}

AI_instance_t *load_ai(char *file)
{
    FILE *in;
    AI_instance_t *ret;
    unsigned char magic[MAGIC_LENGTH];
    long brain_size;
    ret = malloc(sizeof(AI_instance_t));

    in = fopen(file, "r");
    if (in == NULL) {
        perror("fopen");
        return NULL;
    }

    fread(magic, 1, MAGIC_LENGTH, in);
    if (memcmp(magic, ai_mem_magic, MAGIC_LENGTH)) {
        fprintf(stderr, "%s is not a valid AI dump\n", file);
        free(ret);
        fclose(in);
        return NULL;
    }

    fread(ret, 1, sizeof(AI_instance_t), in);


    ret->brain = (int ***)malloc_3d(ret->nr_synapsis / (sizeof(int) * 8),
            ret->nr_ports,  ret->nr_brain_parts, sizeof(int));


    brain_size = (ret->nr_synapsis/(sizeof(int) * 8)) *
        ret->nr_ports/8 * sizeof(int)*ret->nr_brain_parts;
    fread(&ret->brain[0][0][0], 1, brain_size, in);






    fclose(in);

    return ret;
}

void ai_free(AI_instance_t *ai)
{
    free(ai->brain);
    free(ai);
}

int nand(int *a, int *b, int size, piece_t *board, int board_size)
{
    __m128i ad, bd;

    ad = _mm_loadu_si128((__m128i *)a);
    bd = _mm_loadu_si128((__m128i *)b);
    if(!_mm_test_all_zeros(ad, bd))
        return 0;

 

    int i;
    for (i = 0; i < (board_size)/32; i+=4) {
        ad = _mm_loadu_si128((__m128i *)(((int*)board)+i));
        bd = _mm_loadu_si128((__m128i *)((int*)b+(i+(size/32))));
        if(!_mm_test_all_zeros(ad, bd)){            
            return 0;
        }

    }
    return 1;

}

int nand_validation(int *a, int *b, int size, int *board, int board_size)
{

    int i;
    for (i = 0; i < size; i++) {
        if(TestBit(a,i)  && TestBit(b,i)){
            return 0;
        }
    }

    for (i = 0; i < board_size; i++) {
        if(TestBit(board,i)  && TestBit(b,(i+size))){
            return 0;
        }
    }
    return 1;
}

int eval_curcuit(int *V, int **M,  int nr_ports, piece_t *board, int board_size)
{

    int i;
    for (i = 0; i < nr_ports; i++) {
        // if(nand(V, M[i], nr_ports, board, board_size) != nand_validation(V, M[i], nr_ports, board, board_size))
        //     printf("NAND and NAND validation did not return same value\n");


        if (nand(V, M[i], nr_ports, board, board_size))
            SetBit(V,i);
    }
    return !!TestBit(V,(nr_ports-1));
}

int score(AI_instance_t *ai, piece_t *board)
{
    int V[( ai->nr_ports)/32];

    int score_sum = 0;
    int i;
    for(i = 0; i < ai->nr_brain_parts; i++){
        bzero(V, sizeof(V));
        score_sum+= eval_curcuit(V, ai->brain[i], ai->nr_ports, board, ai->board_size);
    }
    
    return score_sum;
}

static int _get_best_move(AI_instance_t *ai, board_t *board)
{
    int i, count, moveret;
    float cumdist[board->moves_count], fcount, x;
    int scores[board->moves_count];

    memcpy(&board->board[64], &board->board[0], 64 * sizeof(piece_t));
    for (i = count = 0; i < board->moves_count; i = ++count) {
        moveret = move(board, i);
       // printf("moveret: %d\n", moveret);
        /* move returns 1 on success */
        if (moveret == 1) {
            scores[i] = score(ai, board->board);
            //printf("score: %d\n", scores[i]);
            undo_move(board, i);
            continue;
        }

        /* move returns -1 if stalemate, 0 if i > board->moves_count */
        if (!moveret)
            break;
        else if (moveret == -1)
            return -1;
    }

    fcount = 0;
    int best_i = 0;
    int best_val = 0;
    for (i = 0; i < board->moves_count; i++) {
        if(scores[i]>best_val){
            best_val=scores[i];
            best_i = i;
        }
    }
    return best_i;
    //x = random_float() * cumdist[board->moves_count - 1];
    //if(bisect(cumdist, x, board->moves_count) >= board->moves_count)
    //    printf("INVALID MOVE RETURNED\n");
    //return bisect(cumdist, x, board->moves_count);
}

//perform a best move return 0 if stalemate, -1 if check mate 1 of success
int do_best_move(AI_instance_t *ai, board_t *board)
{
    int best_move;

    generate_all_moves(board);
    if (is_checkmate(board))
        return -1;
    if (is_stalemate(board) || (best_move = _get_best_move(ai, board)) == -1){
        if (is_checkmate(board))
            return -1;
        
        return 0;
    }

    int ret = do_move(board, best_move);
    if(!ret)
        printf("ret %d\n", ret);
    swapturn(board);
    return 1;
}

//perform a random move return 0 if stalemate, -1 if check mate 1 of success
int do_random_move(board_t *board)
{
    int rndmove;

    do {
        if (is_checkmate(board)) {
            debug_print("checkmate\n");
            return -1;
        }
        if (is_stalemate(board)) {
            debug_print("stalemate\n");
            return 0;
        }
        rndmove = random_int_r(0, board->moves_count - 1);

    } while (!do_move(board, rndmove));

    swapturn(board);

    return 1;
}

//perform a nonrandom move return 0 if stalemate, -1 if check mate 1 of success
int do_nonrandom_move(board_t *board)
{
    int rndmove;

    do {
        if (is_checkmate(board)) {
            debug_print("checkmate\n");
            return -1;
        }
        if (is_stalemate(board)) {
            debug_print("stalemate\n");
            return 0;
        }
        rndmove = 0;

    } while (!do_move(board, rndmove));

    swapturn(board);

    return 1;
}

void punish(AI_instance_t *ai)
{
    ai->nr_losses++;
    ai->nr_games_played++;
}

void small_punish(AI_instance_t *ai)
{
    ai->nr_games_played++;
}

void small_reward(AI_instance_t *ai, int reward){
  ai->positive_reward += reward;
}
void reward(AI_instance_t *ai)
{
    ai->nr_wins+= 1;
    ai->nr_games_played++;
}
void draw(AI_instance_t *ai, board_t * board){
//small_reward(ai, score_board(board));

    ai->nr_games_played++;

}
//brain in a a1 is replaced with brain from a2 pluss a mutation
int mutate(AI_instance_t *a1, AI_instance_t *a2)
{
    int i,j;
    unsigned r1, r2,r3;
    //memcpy(a1, a2, sizeof(AI_instance_t));

   memcpy(&a1->brain[0][0][0], &a2->brain[0][0][0], a1->nr_brain_parts * a1->nr_ports * a1->nr_synapsis / 8);

    
     for (i = 0; i < a1->mutation_rate; i++) {
           int r = random_int_r(0,a1->nr_brain_parts-1);
           r1 = random_int_r(0,a1->nr_ports-1);


           bzero(a1->brain[r][r1], (a1->nr_synapsis/8));

           for(j = 0; j < 10; j++){
                r2 = random_int_r(0,a1->nr_synapsis-1);
                SetBit(a1->brain[r][r1], r2);
            }
     //       r = random_int_r(0,a1->nr_brain_parts-1);
     //       r1 = random_int_r(0,a1->nr_ports-1);

        
    }
    clear_score(a1);
    return 1;
} 
int crossover(AI_instance_t *a1, AI_instance_t *a2, AI_instance_t *a3){
    //int r = random_int_r(0,1);
    return -1;
  }

int score_board(board_t *board){
    int piece_score[13] = { 1, 2, 2, 2, 3, 0,
                           -1, -2, -2. -2, -3, 0,
                            0};
    int i;
    int score = 0;
    for(i = 0; i < 64; i++){
        if(color(board->_board[i]) == WHITE)
            score += piece_score[get_moves_index(board->_board[i])];
        else if(color(board->_board[i]) == BLACK)
            score -= piece_score[get_moves_index(board->_board[i])];

   // printf("score: %d\n", score);
   // printf("move_index: %d\n", get_moves_index(board->_board[i]));

    }
    //print_board(board);
   // printf("score: %d\n", score);
    return score;

}
float get_score(AI_instance_t *ai)
{
    return ((float)(ai->nr_wins))/((float)ai->nr_games_played+1);// + ai->positive_reward/((float)ai->nr_games_played+1);
    //return ((float)(ai->nr_wins))/((float)ai->nr_losses+1);
} 

void clear_score(AI_instance_t *ai)
{
    ai->nr_losses = ai->nr_wins = ai->nr_games_played = ai->positive_reward= 0;
}
