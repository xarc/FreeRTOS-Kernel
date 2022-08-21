#include "tmr_queue.h"
#include "tmr.h"

void enqueue(node_t **head, TASK_FUNCTION_PTR(f)) {
  node_t *new_node = malloc(sizeof(node_t));
  if (!new_node)
    return;

  new_node->val = f;
  new_node->next = *head;

  *head = new_node;
}

void *dequeue(node_t **head) {
  node_t *current, *prev = NULL;
  void *retval = NULL;

  if (*head == NULL)
    return NULL;

  current = *head;
  while (current->next != NULL) {
    prev = current;
    current = current->next;
  }

  retval = current->val;
  free(current);

  if (prev)
    prev->next = NULL;
  else
    *head = NULL;

  return retval;
}

void print_list(node_t *head) {
  node_t *current = head;

  while (current != NULL) {
    printf("%p\n", current->val);
    current = current->next;
  }
}
