#include "FreeRTOS.h"

#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "include/tmr.h"
#include "tmr.h"
#include "tmr_queue.h"

node_t *prvTaskQueue = NULL;
void *prvDataQueue[TMR_QUEUE_LENGTH] = {};

/// initialize TMR queue
void vTmrInit(TASK_FUNCTION_PTR(a), ...) {
  va_list argp;
  va_start(argp, a);
  node_t *q = pvPortMalloc(sizeof(node_t *));
  enqueue(&q, a);

  int i = 0;
  for (; i < TMR_QUEUE_LENGTH - 1; i++) {
    enqueue(&q, va_arg(argp, TASK_FUNCTION_PTR()));
    prvDataQueue[i] = NULL;
  }

  va_end(argp);
  prvTaskQueue = q;
}

/// Find task queue position
int prvTmrFindIndex(TASK_FUNCTION_PTR(f)) {
  int i = 0;
  node_t *q = prvTaskQueue;
  for (; i < TMR_QUEUE_LENGTH; i++) {
    if (q->val == f) {
      return i;
    }
    q = q->next;
  }
  return -1;
}

/// Insert task data to queue
void *iTmrInsertValue(TASK_FUNCTION_PTR(f), void *data) {
  int index = prvTmrFindIndex(f);
  if (index < 0) {
    return NULL;
  }

  prvDataQueue[index] = data;
  return prvDataQueue[index];
}

void vPrintTasks() { return print_list(prvTaskQueue); }

int iTmrPullData() {
  int i = 0;
  for (; i <= TMR_QUEUE_LENGTH - 1; i++) {
    if (prvDataQueue[i] == NULL) {
      return 1;
    }
  }
  return 0;
}

void *iTmrDataByIndex(int i) {
  if (i > TMR_QUEUE_LENGTH - 1) {
    return NULL;
  }
  return prvDataQueue[i];
}

#define CMP(type, index, counter, a, b)                                        \
  ({                                                                           \
    if ((type *)a[i] != (type *)b[i]) {                                        \
      counter++;                                                               \
    }                                                                          \
  })

#define SWITCH_CMP(type, index, counter, a, b)                                 \
  {                                                                            \
    switch (type) {                                                            \
    case CHAR:                                                                 \
      CMP(char, index, counter, a, b);                                         \
      break;                                                                   \
    case INT:                                                                  \
      CMP(int, index, counter, , b);                                           \
      break;                                                                   \
    case FLOAT:                                                                \
      CMP(float, index, counter, a, b);                                        \
      break;                                                                   \
    case DOUBLE:                                                               \
      CMP(double, index, counter, a, b);                                       \
      break;                                                                   \
    }                                                                          \
  }

void *vTmrCompare(TYPE t) {
  void *data[TMR_QUEUE_LENGTH] = {};
  memcpy(data, prvDataQueue, sizeof(data));

  int i;
  int all = 0;
  for (i = 0; i < TMR_QUEUE_LENGTH - 1; i++) {
    SWITCH_CMP(t, i, all, data, prvDataQueue);
  }

  if (all == TMR_QUEUE_LENGTH) {
    return *data;
  }

  if (all == 2) {
    return *data;
  }

  return 0;
}
