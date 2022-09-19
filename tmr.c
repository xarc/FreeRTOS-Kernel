#include "FreeRTOS.h"

#include "FreeRTOSConfig.h"
#include "portable.h"
#include "portmacro.h"
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "semphr.h"
#include <limits.h>

#include "tmr.h"
#include "tmr_queue.h"

node_t *prvTaskQueue = NULL;
struct TmrTask *prvDataQueue[TMR_QUEUE_LENGTH] = {};

struct TmrCtx {
	uint8_t done;
	uint8_t ready;
	uint8_t ok;
	uint8_t err;
	QueueHandle_t data;
};

struct TmrCtx *ctx = NULL;

struct prvTmrQueueData {
	void *data;
	int size;
};

/// initialize TMR queue
void vTmrInit(TASK_FUNCTION_PTR(a), ...)
{
	ctx = pvPortMalloc(sizeof(struct TmrCtx *));
	ctx->data = xQueueCreate(TMR_QUEUE_LENGTH, sizeof(int));

	ctx->ok = 0;
	ctx->done = 0;
	ctx->err = 0;
	ctx->ready = 0;

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
void *iTmrInsertValue(TASK_FUNCTION_PTR(task), void *addr, int size)
{
	struct TmrTask *t = pvPortMalloc(sizeof(struct TmrTask *));
	t->task = task;
	t->addr = addr;
	t->size = size;

	int index = prvTmrFindIndex(t->task);
	if (index < 0) {
		return NULL;
	}

	prvDataQueue[index] = t;
	ctx->ready++;

	int value;
	BaseType_t xTaskWokenByReceive = pdFALSE;

	while (xQueueReceiveFromISR(ctx->data, &value, &xTaskWokenByReceive)) {
		return (void *)value;
	}

	if (xTaskWokenByReceive != pdFALSE) {
		taskYIELD();
	}

	return NULL;
}

void vPrintTasks()
{
	return print_list(prvTaskQueue);
}

int iTmrPullData()
{
	int i = 0;
	for (; i < TMR_QUEUE_LENGTH; i++) {
		if (prvDataQueue[i] == NULL) {
			return 0;
		}
	}
	return 1;
}

void vTmrWaitForData()
{
	while (uxQueueMessagesWaiting(ctx->data) != 0) {
		;
	}
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
#ifdef FT_EXCEPTION_HANDLER
	ft_exception_handler(arg);
#endif
}
#endif

void vTmrCompareV2()
{
	struct TmrTask *data[TMR_QUEUE_LENGTH] = {};

	// TODO: Check if last loop is necessary
	memcpy(data, prvDataQueue, sizeof(data));

	uint8_t *a = (uint8_t *)data[0]->addr;
	uint8_t *b = (uint8_t *)data[1]->addr;
	uint8_t *c = (uint8_t *)data[2]->addr;

	ctx->ok = 1;
	ctx->err = 0;

	int size = data[0]->size;
	int i;
	// we go through bit-by-bit
	for (i = 0; i < size; i++) {
		// most common word
		uint8_t mode = (*a & *b) | (*a & *c) | (*b & *c);
		uint8_t err_a = (*a ^ *b) && (*a ^ *c);
		uint8_t err_b = (*b ^ *a) && (*b ^ *c);
		uint8_t err_c = (*c ^ *a) && (*c ^ *b);

		if (err_a || err_b || err_c) {
			ctx->err = 1;
			if (err_a && err_b && err_c) {
				ctx->ok = 0;
				__asm__ __volatile__("unimp"); // make it burn
			}
		}

		// correct it in case
		*a = mode;
		*b = mode;
		*c = mode;

		a++;
		b++;
		c++;
	}
	ctx->done = 1;

	if (ctx->ok) {
		for (i = 0; i < TMR_QUEUE_LENGTH; i++) {
			xQueueSend(ctx->data, (void *)&a, portMAX_DELAY);
			ctx->ready--;
		}
	}

	vTmrCleanDataQueue();
}

static void vTmrCompareV2Asm()
{
	return vTmrCompareV2();
}
