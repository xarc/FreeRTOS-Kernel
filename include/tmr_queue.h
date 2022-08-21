#ifndef TMR_QUEUE_H_
#define TMR_QUEUE_H_

#include "tmr.h"
#include <stdio.h>
#include <stdlib.h>

/// Queue Node
typedef struct node {
  TASK_FUNCTION_PTR(val);
  struct node *next;
} node_t;

/// Enqueue data to queue
/// @param head Node pointer which points to beginning of the queue
/// @param val Value to store
void enqueue(node_t **head, TASK_FUNCTION_PTR(f));
/// Dequeue data from queue
/// @param head Node pointer which points to beginning of the queue
void *dequeue(node_t **head);
/// Print list
void print_list(node_t *head);

#endif // TMR_QUEUE_H_
