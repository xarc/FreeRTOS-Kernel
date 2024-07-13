/*
 * FreeRTOS Kernel <DEVELOPMENT BRANCH>
 * Copyright (C) 2021 Amazon.com, Inc. or its affiliates.  All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * https://www.FreeRTOS.org
 * https://github.com/FreeRTOS
 *
 */

/*
 * The FreeRTOS kernel's RISC-V port is split between the the code that is
 * common across all currently supported RISC-V chips (implementations of the
 * RISC-V ISA), and code which tailors the port to a specific RISC-V chip:
 *
 * + The code that is common to all RISC-V chips is implemented in
 *   FreeRTOS\Source\portable\GCC\RISC-V-RV32\portASM.S.  There is only one
 *   portASM.S file because the same file is used no matter which RISC-V chip is
 *   in use.
 *
 * + The code that tailors the kernel's RISC-V port to a specific RISC-V
 *   chip is implemented in freertos_risc_v_chip_specific_extensions.h.  There
 *   is one freertos_risc_v_chip_specific_extensions.h that can be used with any
 *   RISC-V chip that both includes a standard CLINT and does not add to the
 *   base set of RISC-V registers.  There are additional
 *   freertos_risc_v_chip_specific_extensions.h files for RISC-V implementations
 *   that do not include a standard CLINT or do add to the base set of RISC-V
 *   registers.
 *
 * CARE MUST BE TAKEN TO INCLDUE THE CORRECT
 * freertos_risc_v_chip_specific_extensions.h HEADER FILE FOR THE CHIP
 * IN USE.  To include the correct freertos_risc_v_chip_specific_extensions.h
 * header file ensure the path to the correct header file is in the assembler's
 * include path.
 *
 * This freertos_risc_v_chip_specific_extensions.h is for use on RISC-V chips
 * that include a standard CLINT and do not add to the base set of RISC-V
 * registers.
 *
 */

#include "portContext.h"

/* Check the freertos_risc_v_chip_specific_extensions.h and/or command line
definitions. */
#if defined( portasmHAS_CLINT ) && defined( portasmHAS_MTIME )
    #error The portasmHAS_CLINT constant has been deprecated.  Please replace it with portasmHAS_MTIME.  portasmHAS_CLINT and portasmHAS_MTIME cannot both be defined at once.  See https://www.FreeRTOS.org/Using-FreeRTOS-on-RISC-V.html
#endif

#ifdef portasmHAS_CLINT
    #warning The portasmHAS_CLINT constant has been deprecated.  Please replace it with portasmHAS_MTIME and portasmHAS_SIFIVE_CLINT.  For now portasmHAS_MTIME and portasmHAS_SIFIVE_CLINT are derived from portasmHAS_CLINT.  See https://www.FreeRTOS.org/Using-FreeRTOS-on-RISC-V.html
    #define portasmHAS_MTIME portasmHAS_CLINT
    #define portasmHAS_SIFIVE_CLINT portasmHAS_CLINT
#endif

#ifndef portasmHAS_MTIME
    #error freertos_risc_v_chip_specific_extensions.h must define portasmHAS_MTIME to either 1 (MTIME clock present) or 0 (MTIME clock not present).  See https://www.FreeRTOS.org/Using-FreeRTOS-on-RISC-V.html
#endif

#ifndef portasmHAS_SIFIVE_CLINT
    #define portasmHAS_SIFIVE_CLINT 0
#endif

.global xPortStartFirstTask
.global pxPortInitialiseStack
.global freertos_risc_v_trap_handler
.global freertos_risc_v_exception_handler
.global freertos_risc_v_interrupt_handler
.global freertos_risc_v_mtimer_interrupt_handler

.extern vTaskSwitchContext
.extern xTaskIncrementTick
// .extern pullMachineTimerCompareRegister
.extern pullNextTime
.extern uxTimerIncrementsForOneTick /* size_t type so 32-bit on 32-bit core and 64-bits on 64-bit core. */
.extern xTaskReturnAddress

.weak freertos_risc_v_application_exception_handler
.weak freertos_risc_v_application_interrupt_handler
/*-----------------------------------------------------------*/

.macro portUPDATE_MTIMER_COMPARE_REGISTER
    // load_x t0, pullMachineTimerCompareRegister  /* Load address of compare register into t0. */
    load_x t1, pullNextTime                     /* Load the address of ullNextTime into t1. */

    #if( __riscv_xlen == 32 )

        /* Update the 64-bit mtimer compare match value in two 32-bit writes. */
        li t4, -1
        lw t2, 0(t1)                /* Load the low word of ullNextTime into t2. */
        lw t3, 4(t1)                /* Load the high word of ullNextTime into t3. */
        //sw t4, 0(t0)                /* Low word no smaller than old value to start with - will be overwritten below. */
        //sw t3, 4(t0)                /* Store high word of ullNextTime into compare register.  No smaller than new value. */
        //sw t2, 0(t0)                /* Store low word of ullNextTime into compare register. */
        ///////////////////////////////////////////////////////////////////////
        csrw 0xBC0, t2

        lw t0, uxTimerIncrementsForOneTick  /* Load the value of ullTimerIncrementForOneTick into t0 (could this be optimized by storing in an array next to pullNextTime?). */
        add t4, t0, t2              /* Add the low word of ullNextTime to the timer increments for one tick (assumes timer increment for one tick fits in 32-bits). */
        sltu t5, t4, t2             /* See if the sum of low words overflowed (what about the zero case?). */
        add t6, t3, t5              /* Add overflow to high word of ullNextTime. */
        sw t4, 0(t1)                /* Store new low word of ullNextTime. */
        sw t6, 4(t1)                /* Store new high word of ullNextTime. */

    #endif /* __riscv_xlen == 32 */

    #if( __riscv_xlen == 64 )

        /* Update the 64-bit mtimer compare match value. */
        ld t2, 0(t1)                /* Load ullNextTime into t2. */
        sd t2, 0(t0)                /* Store ullNextTime into compare register. */
        ld t0, uxTimerIncrementsForOneTick  /* Load the value of ullTimerIncrementForOneTick into t0 (could this be optimized by storing in an array next to pullNextTime?). */
        add t4, t0, t2              /* Add ullNextTime to the timer increments for one tick. */
        sd t4, 0(t1)                /* Store ullNextTime. */

    #endif /* __riscv_xlen == 64 */
    .endm
/*-----------------------------------------------------------*/

/*
 * Unlike other ports pxPortInitialiseStack() is written in assembly code as it
 * needs access to the portasmADDITIONAL_CONTEXT_SIZE constant.  The prototype
 * for the function is as per the other ports:
 * StackType_t *pxPortInitialiseStack( StackType_t *pxTopOfStack, TaskFunction_t pxCode, void *pvParameters );
 *
 * As per the standard RISC-V ABI pxTopcOfStack is passed in in a0, pxCode in
 * a1, and pvParameters in a2.  The new top of stack is passed out in a0.
 *
 * RISC-V maps registers to ABI names as follows (X1 to X31 integer registers
 * for the 'I' profile, X1 to X15 for the 'E' profile, currently I assumed).
 *
 * Register      ABI Name    Description                       Saver
 * x0            zero        Hard-wired zero                   -
 * x1            ra          Return address                    Caller
 * x2            sp          Stack pointer                     Callee
 * x3            gp          Global pointer                    -
 * x4            tp          Thread pointer                    -
 * x5-7          t0-2        Temporaries                       Caller
 * x8            s0/fp       Saved register/Frame pointer      Callee
 * x9            s1          Saved register                    Callee
 * x10-11        a0-1        Function Arguments/return values  Caller
 * x12-17        a2-7        Function arguments                Caller
 * x18-27        s2-11       Saved registers                   Callee
 * x28-31        t3-6        Temporaries                       Caller
 *
 * The RISC-V context is saved t FreeRTOS tasks in the following stack frame,
 * where the global and thread pointers are currently assumed to be constant so
 * are not saved:
 *
 * mstatus
 * xCriticalNesting
 * x31
 * x30
 * x29
 * x28
 * x27
 * x26
 * x25
 * x24
 * x23
 * x22
 * x21
 * x20
 * x19
 * x18
 * x17
 * x16
 * x15
 * x14
 * x13
 * x12
 * x11
 * pvParameters
 * x9
 * x8
 * x7
 * x6
 * x5
 * portTASK_RETURN_ADDRESS
 * [chip specific registers go here]
 * pxCode
 */
pxPortInitialiseStack:
    csrr t0, mstatus                    /* Obtain current mstatus value. */
    andi t0, t0, ~0x8                   /* Ensure interrupts are disabled when the stack is restored within an ISR.  Required when a task is created after the schedulre has been started, otherwise interrupts would be disabled anyway. */
    addi t1, x0, 0x188                  /* Generate the value 0x1880, which are the MPIE and MPP bits to set in mstatus. */
    slli t1, t1, 4
    or t0, t0, t1                       /* Set MPIE and MPP bits in mstatus value. */

    addi a0, a0, -portWORD_SIZE
    store_x t0, 0(a0)                   /* mstatus onto the stack. */
    addi a0, a0, -portWORD_SIZE         /* Space for critical nesting count. */
    store_x x0, 0(a0)                   /* Critical nesting count starts at 0 for every task. */
    addi a0, a0, -(22 * portWORD_SIZE)  /* Space for registers x11-x31. */
    store_x a2, 0(a0)                   /* Task parameters (pvParameters parameter) goes into register X10/a0 on the stack. */
    addi a0, a0, -(6 * portWORD_SIZE)   /* Space for registers x5-x9. */
    load_x t0, xTaskReturnAddress
    store_x t0, 0(a0)                   /* Return address onto the stack. */
    addi t0, x0, portasmADDITIONAL_CONTEXT_SIZE /* The number of chip specific additional registers. */
chip_specific_stack_frame:              /* First add any chip specific registers to the stack frame being created. */
    beq t0, x0, 1f                      /* No more chip specific registers to save. */
    addi a0, a0, -portWORD_SIZE         /* Make space for chip specific register. */
    store_x x0, 0(a0)                   /* Give the chip specific register an initial value of zero. */
    addi t0, t0, -1                     /* Decrement the count of chip specific registers remaining. */
    j chip_specific_stack_frame         /* Until no more chip specific registers. */
1:
    addi a0, a0, -portWORD_SIZE
    store_x a1, 0(a0)                   /* mret value (pxCode parameter) onto the stack. */
    ret
/*-----------------------------------------------------------*/

xPortStartFirstTask:
    load_x  sp, pxCurrentTCB            /* Load pxCurrentTCB. */
    load_x  sp, 0( sp )                 /* Read sp from first TCB member. */

    load_x  x1, 0( sp ) /* Note for starting the scheduler the exception return address is used as the function return address. */

    portasmRESTORE_ADDITIONAL_REGISTERS /* Defined in freertos_risc_v_chip_specific_extensions.h to restore any registers unique to the RISC-V implementation. */

    load_x  x7, 4 * portWORD_SIZE( sp )     /* t2 */
    load_x  x8, 5 * portWORD_SIZE( sp )     /* s0/fp */
    load_x  x9, 6 * portWORD_SIZE( sp )     /* s1 */
    load_x  x10, 7 * portWORD_SIZE( sp )    /* a0 */
    load_x  x11, 8 * portWORD_SIZE( sp )    /* a1 */
    load_x  x12, 9 * portWORD_SIZE( sp )    /* a2 */
    load_x  x13, 10 * portWORD_SIZE( sp )   /* a3 */
    load_x  x14, 11 * portWORD_SIZE( sp )   /* a4 */
    load_x  x15, 12 * portWORD_SIZE( sp )   /* a5 */
    load_x  x16, 13 * portWORD_SIZE( sp )   /* a6 */
    load_x  x17, 14 * portWORD_SIZE( sp )   /* a7 */
    load_x  x18, 15 * portWORD_SIZE( sp )   /* s2 */
    load_x  x19, 16 * portWORD_SIZE( sp )   /* s3 */
    load_x  x20, 17 * portWORD_SIZE( sp )   /* s4 */
    load_x  x21, 18 * portWORD_SIZE( sp )   /* s5 */
    load_x  x22, 19 * portWORD_SIZE( sp )   /* s6 */
    load_x  x23, 20 * portWORD_SIZE( sp )   /* s7 */
    load_x  x24, 21 * portWORD_SIZE( sp )   /* s8 */
    load_x  x25, 22 * portWORD_SIZE( sp )   /* s9 */
    load_x  x26, 23 * portWORD_SIZE( sp )   /* s10 */
    load_x  x27, 24 * portWORD_SIZE( sp )   /* s11 */
    load_x  x28, 25 * portWORD_SIZE( sp )   /* t3 */
    load_x  x29, 26 * portWORD_SIZE( sp )   /* t4 */
    load_x  x30, 27 * portWORD_SIZE( sp )   /* t5 */
    load_x  x31, 28 * portWORD_SIZE( sp )   /* t6 */

    load_x  x5, 29 * portWORD_SIZE( sp )    /* Obtain xCriticalNesting value for this task from task's stack. */
    load_x  x6, pxCriticalNesting           /* Load the address of xCriticalNesting into x6. */
    store_x x5, 0( x6 )                     /* Restore the critical nesting value for this task. */

    load_x  x5, 30 * portWORD_SIZE( sp )    /* Initial mstatus into x5 (t0). */
    addi    x5, x5, 0x08                    /* Set MIE bit so the first task starts with interrupts enabled - required as returns with ret not eret. */
    csrrw   x0, mstatus, x5                 /* Interrupts enabled from here! */

    load_x  x5, 2 * portWORD_SIZE( sp )     /* Initial x5 (t0) value. */
    load_x  x6, 3 * portWORD_SIZE( sp )     /* Initial x6 (t1) value. */

    addi    sp, sp, portCONTEXT_SIZE
    ret
/*-----------------------------------------------------------*/

freertos_risc_v_application_exception_handler:
    addi    sp, sp, -4                                     # decrement stack pointer
    sw      ra, 0(sp)                                      # save return address
    
    csrr t0, mcause     /* For viewing in the debugger only. */
    csrr t1, mepc       /* For viewing in the debugger only */
    csrr t2, mstatus    /* For viewing in the debugger only */

    /* Report all HARV event report */
#include "defines.h"

#ifndef SKIP_TRAP_REPORT
harv_exception_report_trap_info:
    /* print TRAP */
    li      a0, 0x0A
    call    asm_putchar
    li      a0, 0x54
    call    asm_putchar
    li      a0, 0x52
    call    asm_putchar
    li      a0, 0x41
    call    asm_putchar
    li      a0, 0x50
    call    asm_putchar
    li      a0, 0x0A
    call    asm_putchar

    csrr    a0, CSR_HARDEN_CONF_ADDR
    li      a1, 8
    call    asm_write_hex

    csrr    a0, mepc
    li      a1, 8
    call    asm_write_hex

    csrr    a0, mcause
    li      a1, 8
    call    asm_write_hex

#if EH_ENABLED == 1
    # PRINT EVENT INFORMATION
    li      a0, EH_EVENT_ID
    lw      a0, 0(a0)
    li      a1, 4
    call    asm_write_hex
    
    li      a0, EH_PC
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_INSTR
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_ENC_DATA
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_ENC_DATA_ECC
    lw      a0, 0(a0)
    li      a1, 2
    call    asm_write_hex

    li      a0, EH_ALU_RESULT
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_MCYCLE
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_MCYCLEH
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_JALLOG_PTR
    lw      a0, 0(a0)
    li      a1, 3
    call    asm_write_hex

    li      a0, EH_JALLOG_SIZE
    lw      a0, 0(a0)
    mv      s1, a0
    li      a1, 3
    call    asm_write_hex

    li      s0, EH_JALLOG_BASE   # load JALLOG base address to s0
    sll     s1, s1, 2            # multiply jallog size by 4
    add     s1, s0, s1           # get high address
loop_jallog:
    lw      a0, 0(s0)            # read JALLOG data
    li      a1, 8                # set number of digits to print
    call    asm_write_hex        # call hex write print
    addi    s0, s0, 4            # increment JALLOG pointer to data
    bltu    s0, s1, loop_jallog  # if it's not last address, loop
#endif

    ## MEM event handler
#if MEM_EH_ENABLED == 1
    li      a0, MEM_EH_EVENT_ID
    lw      a0, 0(a0)
    li      a1, 1
    call    asm_write_hex

    li      a0, MEM_EH_MEM_ADDR
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, MEM_EH_MEM_ECC_ADDR
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, MEM_EH_ENC_DATA
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, MEM_EH_ENC_DATA_ECC
    lw      a0, 0(a0)
    li      a1, 2
    call    asm_write_hex

    li      a0, MEM_EH_MEM_PREV_ADDR
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, MEM_EH_ENABLE
    lw      a0, 0(a0)
    li      a1, 1
    call    asm_write_hex
#endif
#endif

#if MEM_EH_ENABLED == 1
    /* error correction of memory events */
    li      a0, MEM_EH_EVENT_ID              # load event id address
    lw      a0, 0(a0)                        # read memory event id
    beq     a0, x0, skip_correction          # if there are no memory events, skips correction
    li      s0, MEM_EH_MEM_ADDR              # load address of error address
    lw      s0, 0(s0)                        # read error address
    la      t0, MEM_EH_BASE_MEM_ADDR         # load memory base address
    add     s0, s0, t0                       # increment with base RAM address
    lw      s1, 0(s0)                        # read data with error
    sw      s1, 0(s0)                        # write data back to memory to remove the ecc error
skip_correction:
#endif

#if CMEM_EH_ENABLED == 1

    ## CMEM event handler
    li      a0, CMEM_EH_EVENT_ID
    lw      a0, 0(a0)
    li      a1, 2
    call    asm_write_hex

    li      a0, CMEM_EH_SYNDROME
    lw      a0, 0(a0)
    li      a1, 4
    call    asm_write_hex

    li      a0, CMEM_EH_FAR
    lw      a0, 0(a0)
    li      a1, 7
    call    asm_write_hex

    li      a0, CMEM_EH_SYNWORD
    lw      a0, 0(a0)
    li      a1, 2
    call    asm_write_hex

    li      a0, CMEM_EH_SYNBIT
    lw      a0, 0(a0)
    li      a1, 2
    call    asm_write_hex

    li      a0, CMEM_EH_ADDITIONAL
    lw      a0, 0(a0)
    li      a1, 1
    call    asm_write_hex

    li      a0, CMEM_EH_ECCERROR
    lw      a0, 0(a0)
    li      a1, 1
    call    asm_write_hex

    li      a0, CMEM_EH_CRCERROR
    lw      a0, 0(a0)
    li      a1, 1
    call    asm_write_hex

#endif

    /* error correction of memory events */
    li      a0, MEM_EH_EVENT_ID                            # load event id address
    lw      a0, 0(a0)                                      # read memory event id
    beq     a0, x0, harv_report_trap_info_skip_correction  # if there are no memory events, skips correction
    li      s0, MEM_EH_MEM_ADDR                            # load address of error address
    lw      s0, 0(s0)                                      # read error address
    la      t0, RAM_BASE_ADDR                              # load memory base address
    add     s0, s0, t0                                     # increment with base RAM address
    lw      s1, 0(s0)                                      # read data with error
    sw      s1, 0(s0)                                      # write data back to memory to remove the ecc error
harv_report_trap_info_skip_correction:

#if (FAULT_TRAP_HANDLER != 0)
    csrr    a0, mcause                                     # read mcause csr
    csrr    a1, mepc                                       # read mepc csr
    li      a2, EH_EVENT_ID                                # get event handler address
    lw      a2, 0(a2)                                      # get processor event id
    li      a3, MEM_EH_EVENT_ID                            # get memory event handler address
    lw      a3, 0(a3)                                      # get memory eventh handler id
    call    FAULT_TRAP_HANDLER
    lw      ra, 0(sp)                                      # restore return address
    addi    sp, sp, 4                                      # increment stack pointer
    ret
#else
    csrr    a0, mcause                       # read trap cause CSR
    li      a1, 0x00000018                   # load event handler trap cause value
    beq     a0, a1, handle_hfte              # branch if is custom trap from HARV (HFTE)
    /* _else: UNRECOVERABLE except, reset SoC using WDT */
exc_reset_soc:
    li      a0,   WDT_ADDR                   # load watchdog timer address
    sw      zero, 0(a0)                      # write zero to watchdog timer to trigger reset
    j       exc_reset_soc                    # ensure SoC reset

    /* HARV exception handler */
handle_hfte:
#if CMEM_EH_ENABLED == 1
    li      a0, CMEM_EH_EVENT_ID             # load CMEM event id address
    lw      a0, 0(a0)                        # load CMEM event id
    beqz    a0, trap_return                  # branch if it is not a CMEM event
    andi    a0, a0, 0b0100                   # mask to get DOUBLE BIT UPSET flag
    beqz    a0, trap_return                  # branch if is not a DBU
                                             # _else: trigger fpga reprogram
exc_reprogram_fpga:
    /* print RP\n */
    li      a0, 0x52
    call    asm_putchar
    li      a0, 0x50
    call    asm_putchar
    li      a0, 0xA
    call    asm_putchar
    /* trigger fpga reprogramming */
    li      a0, GPIO_CONF_ADDR               # get GPIO configuration address
    sw      x0, 0(a0)                        # configure all ports as outputs
    li      a0, GPIO_BASE_ADDR               # get base GPIO address
    li      a1, 0b1110                       # get data to write to GPIOs
    sw      a1, 0(a0)                        # write 1 to GPIOs 3, 2, and 1
    j       exc_reprogram_fpga               # ensure reprogram
#endif
    /* return to normal execution, fault is from harv */
    lw      ra, 0(sp)                                      # restore return address
    addi    sp, sp, 4                                      # increment stack pointer
    ret                                                    # return to the application execution

#endif

##############################################
asm_putchar:
wait_uart0:
    li      t0, UART_STATUS_ADDR     # load UART status address
    lw      t1, 0(t0)                # load status into t1
    srl     t1, t1, 1                # shift t1 right by one bit
    and     t1, t1, 1                # filter uart ready status code
    li      t2, 1                    # load comparison value
    beq     t1, t2, wait_uart0       # branch if status is not ready
write_uart_byte:
    li      t0, UART_INTERFACE_ADDR
    sb      a0, 0(t0)
wait_uart1:
    li      t0, UART_STATUS_ADDR     # load UART status address
    lw      t1, 0(t0)                # load status into t1
    srl     t1, t1, 1                # shift t1 right by one bit
    and     t1, t1, 1                # filter uart ready status code
    li      t2, 1                    # load comparison value
    beq     t1, t2, wait_uart1       # branch if status is not ready
    ret                              # _else: return
##################################
asm_write_hex:
    mv      t6, ra                # save return address to t6
    mv      t3, a0                # save number to print to t3
    mv      t4, a1                # save number of digits to t4
awh_loop:
    addi    t4, t4, -1            # decrement number of digits
    sll     t1, t4, 2             # multiply number of digits by 4
    srl     t0, t3, t1            # shifts value for next digit
    andi    t0, t0, 0xF           # get one digit -> t5
    addi    t0, t0, 0x30          # increments 0x30 to convert to char
    li      t1, 0x39              # load comparison value
    ble     t0, t1, awh_print     # if digit is number [0-9], jumps to print
    addi    t0, t0, 0x7           # increment for hex char values [A-F]
awh_print:
    mv      a0, t0                # load char to argument
    call    asm_putchar           # call putchar function
awh_end_loop:
    bgt     t4, x0, awh_loop      # if number is greater than zero, loop
awh_end:
    li      a0, 0x0A              # load line break char
    call    asm_putchar           # call putchar function
    mv      ra, t6                # load return address
    ret
/*-----------------------------------------------------------*/

freertos_risc_v_application_interrupt_handler:
    csrr t0, mcause     /* For viewing in the debugger only. */
    csrr t1, mepc       /* For viewing in the debugger only */
    csrr t2, mstatus    /* For viewing in the debugger only */
    j .
/*-----------------------------------------------------------*/

.section .text.freertos_risc_v_exception_handler
freertos_risc_v_exception_handler:
    portcontextSAVE_EXCEPTION_CONTEXT
    /* a0 now contains mcause. */
    li t0, 11                           /* 11 == environment call. */
    bne a0, t0, other_exception         /* Not an M environment call, so some other exception. */
    call vTaskSwitchContext
    portcontextRESTORE_CONTEXT

other_exception:
    call freertos_risc_v_application_exception_handler
    portcontextRESTORE_CONTEXT
/*-----------------------------------------------------------*/

.section .text.freertos_risc_v_interrupt_handler
freertos_risc_v_interrupt_handler:
    portcontextSAVE_INTERRUPT_CONTEXT
    call freertos_risc_v_application_interrupt_handler
    portcontextRESTORE_CONTEXT
/*-----------------------------------------------------------*/

.section .text.freertos_risc_v_mtimer_interrupt_handler
freertos_risc_v_mtimer_interrupt_handler:
    portcontextSAVE_INTERRUPT_CONTEXT
    portUPDATE_MTIMER_COMPARE_REGISTER
    call xTaskIncrementTick
    beqz a0, exit_without_context_switch    /* Don't switch context if incrementing tick didn't unblock a task. */
    call vTaskSwitchContext
exit_without_context_switch:
    portcontextRESTORE_CONTEXT
/*-----------------------------------------------------------*/

.section .text.freertos_risc_v_trap_handler
.align 8
freertos_risc_v_trap_handler:
    portcontextSAVE_CONTEXT_INTERNAL

    csrr a0, mcause
    csrr a1, mepc

    bge a0, x0, synchronous_exception

asynchronous_interrupt:
    store_x a1, 0( sp )                 /* Asynchronous interrupt so save unmodified exception return address. */
    load_x sp, xISRStackTop             /* Switch to ISR stack. */
    j handle_interrupt

synchronous_exception:
    li   t0, 0x18                       /* load immediate for event handler faults */
    beq  a0, t0, skip_pc_increment      /* in case it is an event from event handler, skip increment of PC to reexecute instruction */
    addi a1, a1, 4                      /* Synchronous so update exception return address to the instruction after the instruction that generated the exception. */
skip_pc_increment:
    store_x a1, 0( sp )                 /* Save updated exception return address. */
    load_x sp, xISRStackTop             /* Switch to ISR stack. */
    j handle_exception

handle_interrupt:
#if( portasmHAS_MTIME != 0 )

    test_if_mtimer:                     /* If there is a CLINT then the mtimer is used to generate the tick interrupt. */
        addi t0, x0, 1
        slli t0, t0, __riscv_xlen - 1   /* LSB is already set, shift into MSB.  Shift 31 on 32-bit or 63 on 64-bit cores. */
        addi t1, t0, 7                  /* 0x8000[]0007 == machine timer interrupt. */
        bne a0, t1, application_interrupt_handler

        portUPDATE_MTIMER_COMPARE_REGISTER
        call xTaskIncrementTick
        beqz a0, processed_source       /* Don't switch context if incrementing tick didn't unblock a task. */
        call vTaskSwitchContext
        j processed_source

#endif /* portasmHAS_MTIME */

application_interrupt_handler:
    call freertos_risc_v_application_interrupt_handler
    j processed_source

handle_exception:
    /* a0 contains mcause. */
    li t0, 11                                   /* 11 == environment call. */
    bne a0, t0, application_exception_handler   /* Not an M environment call, so some other exception. */
    call vTaskSwitchContext
    j processed_source

application_exception_handler:
    call freertos_risc_v_application_exception_handler
    j processed_source                  /* No other exceptions handled yet. */

processed_source:
    portcontextRESTORE_CONTEXT
/*-----------------------------------------------------------*/
