#include "FreeRTOS.h"

#include "FreeRTOSConfig.h"
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "include/tmr.h"
#include "tmr.h"
#include "tmr_queue.h"

node_t *prvTaskQueue = NULL;
void *prvDataQueue[TMR_QUEUE_LENGTH] = {};

/// initialize TMR queue
void vTmrInit(TASK_FUNCTION_PTR(a), ...)
{
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
int prvTmrFindIndex(TASK_FUNCTION_PTR(f))
{
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
void *iTmrInsertValue(TASK_FUNCTION_PTR(f), void *data)
{
	int index = prvTmrFindIndex(f);
	if (index < 0) {
		return NULL;
	}

	prvDataQueue[index] = data;
	return prvDataQueue[index];
}

void vPrintTasks()
{
	return print_list(prvTaskQueue);
}

int iTmrPullData()
{
	int i = 0;
	for (; i <= TMR_QUEUE_LENGTH - 1; i++) {
		if (prvDataQueue[i] == NULL) {
			return 1;
		}
	}
	return 0;
}

void *iTmrDataByIndex(int i)
{
	if (i > TMR_QUEUE_LENGTH - 1) {
		return NULL;
	}
	return prvDataQueue[i];
}

void vTmrCleanDataQueue()
{
	int i;

	for (i = 0; i < TMR_QUEUE_LENGTH - 1; i++) {
		prvDataQueue[i] = NULL;
	}
}

void *vTmrCompare(TYPE t)
{
	if (iTmrPullData())
		return NULL;

	void *data[TMR_QUEUE_LENGTH] = {};
	memcpy(data, prvDataQueue, sizeof(data));

	int i;
	for (i = 0; i < TMR_QUEUE_LENGTH - 1; i++) {
		data[i] = prvDataQueue[i];
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
		if ((int *)data[0] == (int *)data[1] ||
		    (int *)data[0] == (int *)data[2]) {
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

#ifdef FT_EXCEPTION_HANDLER
void exception_handler(void *arg)
{
	printf("%p\n", arg);

#ifdef FT_EXCEPTION_HANDLER
	ft_exception_handler(arg);
#endif
}
#endif

struct result {
	void *addr;
	int size;
};

struct result *prvDataResultsQueue[TMR_QUEUE_LENGTH] = {};

void vTmrCompareV2()
{
	struct result *data[TMR_QUEUE_LENGTH] = {};

	// TODO: Check if last loop is necessary
	memcpy(data, prvDataQueue, sizeof(data));

	int i;
	for (i = 0; i < TMR_QUEUE_LENGTH - 1; i++) {
		data[i] = prvDataQueue[i];
	}

	uint8_t *a = (uint8_t *)data[0]->addr;
	uint8_t *b = (uint8_t *)data[1]->addr;
	uint8_t *c = (uint8_t *)data[2]->addr;

	// TODO: change in main.c to use struct result

	// we go through byte by byte
	for (i = 0; i < data[0]->size; i++) {
		// valor mais comum
		uint8_t moda = (*a & *b) | (*a & *c) | (*b & *c);
		uint8_t err_a = (*a ^ *b) | (*a ^ *c);
		uint8_t err_b = (*b ^ *a) | (*b ^ *c);
		uint8_t err_c = (*c ^ *a) | (*c ^ *b);

		if (err_a || err_b || err_c) {
			if (err_a && err_b && err_c) {
				printf("Unfixable error. Aborting.\n");
				__asm__ __volatile__("unimp"); // make it burn
			} else {
				printf("error in one of values. Trying to fix it..\n");
			}
		}

		// correct it in case
		*a = moda;
		*b = moda;
		*c = moda;

		a++;
		b++;
		c++;
	}

	//// valor mais comum
	//uint8_t moda = (*a & *b) | (*a & *c) | (*b & *c);
	//uint8_t err_a = (*a ^ *b) | (*a ^ *c);
	//uint8_t err_b = (*b ^ *a) | (*b ^ *c);
	//uint8_t err_c = (*c ^ *a) | (*c ^ *b);

	//if (err_a == 0 && err_b == 0 && err_c == 0) {
	//	return (void *)data[0];
	//}
}
