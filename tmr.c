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

void vTmrCleanDataQueue() {
  int i;

  for (i = 0; i < TMR_QUEUE_LENGTH - 1; i++) {
    prvDataQueue[i] = NULL;
  }
}

void *vTmrCompare(TYPE t) {
  if (iTmrPullData())
    return NULL;

  void *data[TMR_QUEUE_LENGTH] = {};
  memcpy(data, prvDataQueue, sizeof(data));

  int i;
  for (i = 0; i < TMR_QUEUE_LENGTH - 1; i++) {
    data[i] = prvDataQueue[0];
  }

  switch (t) {
  case CHAR:
    if ((char *)data[0] == (char *)data[1] ||
        (char *)data[0] == (char *)data[2]) {
      return data[0];
    }

    if ((char *)data[1] == (char *)data[2]) {
      return data[1];
    }
    break;
  case INT:
    if ((int *)data[0] == (int *)data[1] || (int *)data[0] == (int *)data[2]) {
      return data[0];
    }

    if ((int *)data[1] == (int *)data[2]) {
      return data[1];
    }
    break;
  case FLOAT:
    if ((float *)data[0] == (float *)data[1] ||
        (float *)data[0] == (float *)data[2]) {
      return data[0];
    }

    if ((float *)data[1] == (float *)data[2]) {
      return data[1];
    }
    break;
  case DOUBLE:
    if ((double *)data[0] == (double *)data[1] ||
        (double *)data[0] == (double *)data[2]) {
      return data[0];
    }

    if ((double *)data[1] == (double *)data[2]) {
      return data[1];
    }
    break;
  default:
    break;
  }

  return NULL;
}
