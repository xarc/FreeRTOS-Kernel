#include "FreeRTOS.h"

#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

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
  for (; i <= TMR_QUEUE_LENGTH; i++) {
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
  for (; i < TMR_QUEUE_LENGTH - 1; i++) {
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
