#ifndef TMR_H_
#define TMR_H_

#include <stddef.h>

#define TMR_SECTION __attribute__((section(".tmr")))

#ifndef TMR_QUEUE_LENGTH
#define TMR_QUEUE_LENGTH 3
#endif

typedef enum { CHAR, INT, FLOAT, DOUBLE } TYPE;

/// Function pointer to FreeRTOS
#define TASK_FUNCTION_PTR(x) void (*x)(void *)

/// Initialize a set of tasks as a TMR-based task.
void vTmrInit(TASK_FUNCTION_PTR(f), ...);
// Print current setup tasks to stdout.
void vPrintTasks();

/// TMR insert task value to storage
void *iTmrInsertValue(TASK_FUNCTION_PTR(f), void *data);

// check if data is full
int iTmrPullData();

// check if data is full
void *iTmrDataByIndex(int);

// compare values in queue
void *vTmrCompare(TYPE);

// Clean data queue;
void vTmrCleanDataQueue();

void exception_handler(void *);

#ifdef FT_EXCEPTION_HANDLER
void __attribute__((weak))
freertos_risc_v_application_exception_handler(void *arg)
{
	exception_handler(arg);
	__asm__ __volatile__("mret");
}
#endif

#endif // TMR_H_
