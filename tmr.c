#include "FreeRTOS.h"

#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#include "tmr.h"
#include "tmr_queue.h"

node_t *prvQueue = NULL;

// initialize TMR queue
void vTmrInit(TASK_FUNCTION_PTR(a), ...) {
  va_list argp;
  va_start(argp, a);

  int i = 0;
  for (; i < TMR_QUEUE_LENGTH; i++) {
    enqueue(&prvQueue, va_arg(argp, TASK_FUNCTION_PTR()));
  }

  va_end(argp);
}

void vPrintTasks() { return print_list(prvQueue); }
