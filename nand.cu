#include <stdio.h>
#include <unistd.h>

#include "common.h"
#include "AI.h"
#include "board.h"
#include "nand.h"
__device__ int result;

__device__ int cu_nand(piece_t *data, int *brain, int size, int idx) {
    if (data[idx] & brain[idx])
        data[size-1] = 0;
}

__global__ void cu_eval_curcuit(int* brainpart_value, int *M, int nr_ports,
        int *board, int board_size) {
    const int data_size = 128 / 2 + 128 / 32 + 1;
    __shared__ piece_t data[data_size];
   
    if(threadIdx.x < 128)
        data[threadIdx.x] = board[threadIdx.x];
    else
        data[threadIdx.x-128] = 0;
        
    __syncthreads();

    int brain_idx = blockIdx.x;
    int i;
    int size_port = nr_ports / 32 + 128 / 2;
    int brain = brain_idx * (nr_ports * size_port);


    for (i = 0; i < nr_ports; i++) {
        //get the value of port i using a offset
        data[data_size - 1] = 1;
        cu_nand(data, M + brain + i, data_size, threadIdx.x);
        __syncthreads();
        if (threadIdx.x == 1 && blockIdx.x == 1 && data[data_size - 1])
            SetBit(&data[128 / 2], i);


    }
    brainpart_value[brain_idx] = !!TestBit(&data[128 / 2], (nr_ports - 1));

}
__global__ void cu_eval_curcuit2(int* brainpart_value, int *M, int nr_ports,
        int *board, int board_size) {
    const int data_size = 128 / 2 + 128 / 32 + 1;
    __shared__ piece_t data[data_size];
   
    if(threadIdx.x < 128)
        data[threadIdx.x] = board[threadIdx.x];
    else
        data[threadIdx.x-128] = 0;
        
    __syncthreads();

    int brain_idx = blockIdx.x;
    int i;
    int size_port = nr_ports / 32 + 128 / 2;
    int brain = brain_idx * (nr_ports * size_port);


    for (i = 0; i < nr_ports; i++) {
        //get the value of port i using a offset
        data[data_size - 1] = 1;
        cu_nand(data, M + brain + i, data_size, threadIdx.x);
        __syncthreads();
        if (threadIdx.x == 1 && blockIdx.x == 1 && data[data_size - 1])
            SetBit(&data[128 / 2], i);


    }
    brainpart_value[brain_idx] = !!TestBit(&data[128 / 2], (nr_ports - 1));

}



int cu_score(AI_instance_t *ai, board_t *board) {

    //piece_t *cu_board;
    int *cu_brainpart_value;
    int *brainpart_value;
 
    //allocate memory for CUDA
    //cudaMalloc(&cu_board, sizeof(piece_t)*64);
    cudaMalloc(&cu_brainpart_value, ai->nr_brain_parts * sizeof (int));
    brainpart_value = (int *) malloc(ai->nr_brain_parts * sizeof (int));

    cudaMemcpyAsync(board->cu_board, board->board, sizeof (piece_t) * 128,
            cudaMemcpyHostToDevice,  ai->stream);
    cu_eval_curcuit << <ai->nr_ports / 32 + 128 / 2, ai->nr_brain_parts, 0, ai->stream>>>
            (cu_brainpart_value, ai->cu_brain, ai->nr_ports,
            (int*) board->cu_board, ai->board_size);


    //wait for all the brain parts to finish

    //get the results from each brain part
    cudaMemcpyAsync(brainpart_value, cu_brainpart_value,
            ai->nr_brain_parts * sizeof (int), cudaMemcpyDeviceToHost, ai->stream);
    
    //if (cudaDeviceSynchronize())
    //    printf("synch error\n");
    cudaStreamSynchronize ( ai->stream );

    int score_sum = 0;
    int i;
    for (i = 0; i < ai->nr_brain_parts; i++) {
        score_sum += brainpart_value[i];
    }
    //free the allocated memory
    cudaFree(cu_brainpart_value);
    free(brainpart_value);
    return score_sum;
}
