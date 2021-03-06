/* $Header: alpha-assem.S,v 1.4 94/06/10 20:34:10 hallgren Exp $ */
#include <machine/regdef.h>
#include <machine/pal.h>

#include "internals.h"
#include "lispregs.h"

/*
 * Function to transfer control into lisp.
 */
	.text
	.align	4
	.globl	call_into_lisp
	.ent	call_into_lisp
call_into_lisp:
#define framesize 8*8
	ldgp	gp, 0($27)             /*     ###   */
	/* Save all the C regs. */
	lda	sp,-framesize(sp)
	stq	ra, framesize-8*8(sp)
	stq	s0, framesize-8*7(sp)
	stq	s1, framesize-8*6(sp)
	stq	s2, framesize-8*5(sp)
	stq	s3, framesize-8*4(sp)
	stq	s4, framesize-8*3(sp)
	stq	s5, framesize-8*2(sp)
	stq	s6, framesize-8*1(sp)
	.mask	0x0fc001fe, -framesize
	.frame	sp,framesize,ra

	/* Clear descriptor regs */
	ldil	reg_CODE,0
	ldil	reg_FDEFN,0
	mov	a0,reg_LEXENV
	sll	a2,2,reg_NARGS
	ldil	reg_OCFP,0
	ldil	reg_LRA,0
	ldil	reg_L0,0
	ldil	reg_L1,0
	

	/* Establish NIL. */
	ldil	reg_NULL,NIL

	/* Start pseudo-atomic. */

	/* No longer in foreign call. */
	stl	zero,foreign_function_call_active

	/* Load lisp state. */
	ldl	reg_ALLOC,current_dynamic_space_free_pointer
	ldl	reg_BSP,current_binding_stack_pointer
	ldl	reg_CSP,current_control_stack_pointer
	ldl	reg_OCFP,current_control_frame_pointer
	mov	a1,reg_CFP

	.set	noat
	ldil	reg_L2,0
	/* End of pseudo-atomic. */

	/* Establish lisp arguments. */
	ldl	reg_A0,0(reg_CFP)
	ldl	reg_A1,4(reg_CFP)
	ldl	reg_A2,8(reg_CFP)
	ldl	reg_A3,12(reg_CFP)
	ldl	reg_A4,16(reg_CFP)
	ldl	reg_A5,20(reg_CFP)

	/* Calculate the LRA. */
	lda	reg_LRA,call_into_lisp_LRA_page+type_OtherPointer

	/* Indirect the closure */
	ldl	reg_CODE,CLOSURE_FUNCTION_OFFSET(reg_LEXENV)
	addl	reg_CODE,6*4-type_FunctionPointer,reg_LIP

	/* And into lisp we go. */
	jsr	reg_ZERO,(reg_LIP)

	.set noreorder
	.align	3
	.globl	call_into_lisp_LRA
call_into_lisp_LRA:	

	.word	type_ReturnPcHeader

	mov	reg_OCFP,reg_CSP
	nop

	/* return value already there */
	mov	reg_A0,v0

	/* Turn on pseudo-atomic. */

	/* Save LISP registers */
	stl	reg_ALLOC,current_dynamic_space_free_pointer
	stl	reg_BSP,current_binding_stack_pointer
	stl	reg_CSP,current_control_stack_pointer
	stl	reg_CFP,current_control_frame_pointer

	/* Back in C land.  [CSP is just a handy non-zero value.] */
	stl	reg_CSP,foreign_function_call_active

	/* Turn off pseudo-atomic and check for traps. */
	
	/* Restore C regs */
	ldq	ra, framesize-8*8(sp)
	ldq	s0, framesize-8*7(sp)
	ldq	s1, framesize-8*6(sp)
	ldq	s2, framesize-8*5(sp)
	ldq	s3, framesize-8*4(sp)
	ldq	s4, framesize-8*3(sp)
	ldq	s5, framesize-8*2(sp)
	ldq	s6, framesize-8*1(sp)

	ret	zero,(ra),1
	.globl	call_into_lisp_end
call_into_lisp_end:
	.end	call_into_lisp

/*
 * Transfering control from Lisp into C
 */
	.set noreorder
	.text
	.align	4
	.globl	call_into_c
	.ent	call_into_c
call_into_c:
	.mask	0x0fc001fe, -12
	.frame	sp,12,ra
	mov	reg_CFP, reg_OCFP
	mov	reg_CSP, reg_CFP
	addq	reg_CFP, 32, reg_CSP
	stl	reg_OCFP, 0(reg_CFP)
	subl	reg_LIP, reg_CODE, reg_L1
	addl	reg_L1, type_OtherPointer, reg_L1
	stl	reg_L1, 4(reg_CFP)
	stl	reg_CODE, 8(reg_CFP)
	stl	reg_NULL, 12(reg_CFP)

	/* Set the pseudo-atomic flag. */
	addq	reg_ALLOC,1,reg_ALLOC

	/* Get the top two register args and fix the NSP to point to arg 7 */
	ldq	reg_NL4,0(reg_NSP)
	ldq	reg_NL5,8(reg_NSP)
	addq	reg_NSP,16,reg_NSP

	/* Save lisp state. */
	subq	reg_ALLOC,1,reg_L1
	stl	reg_L1, current_dynamic_space_free_pointer
	stl	reg_BSP, current_binding_stack_pointer
	stl	reg_CSP, current_control_stack_pointer
	stl	reg_CFP, current_control_frame_pointer

	/* Mark us as in C land. */
	stl	reg_CSP, foreign_function_call_active

	/* Were we interrupted? */
	subq	reg_ALLOC,1,reg_ALLOC
	stl	reg_ZERO,0(reg_ALLOC)

	/* Into C land we go. */
	mov	reg_CFUNC, reg_L1    /* ### This line is a mystery */
	jsr	ra, (reg_CFUNC)
	ldgp	$29,0(ra)

	/* restore NSP */
	subq	reg_NSP,16,reg_NSP

	/* Clear unsaved descriptor regs */
	mov	reg_ZERO, reg_NARGS
	mov	reg_ZERO, reg_A0
	mov	reg_ZERO, reg_A1
	mov	reg_ZERO, reg_A2
	mov	reg_ZERO, reg_A3
	mov	reg_ZERO, reg_A4
	mov	reg_ZERO, reg_A5
	mov	reg_ZERO, reg_L0
	mov	reg_ZERO, reg_L2

	/* Turn on pseudo-atomic. */
	lda	reg_ALLOC,1(reg_ZERO)

	/* Mark us at in Lisp land. */
	stl	reg_ZERO, foreign_function_call_active

	/* Restore ALLOC, preserving pseudo-atomic-atomic */
	ldl	reg_NL0,current_dynamic_space_free_pointer
	addq	reg_ALLOC,reg_NL0,reg_ALLOC
	
	/* Check for interrupt */
	subq	reg_ALLOC,1,reg_ALLOC
	stl	reg_ZERO,0(reg_ALLOC)

	ldl	reg_NULL, 12(reg_CFP)

	/* Restore LRA & CODE (they may have been GC'ed) */
	ldl	reg_CODE, 8(reg_CFP)
	ldl	reg_NL0, 4(reg_CFP)
	subq	reg_NL0, type_OtherPointer, reg_NL0
	addq	reg_CODE, reg_NL0, reg_NL0

	mov	reg_CFP, reg_CSP
	mov	reg_OCFP, reg_CFP

	ret	zero, (reg_NL0), 1

	.end	call_into_c

	.text
	.globl	start_of_tramps
start_of_tramps:

/*
 * The undefined-function trampoline.
 */
        .text
        .globl  undefined_tramp
        .ent    undefined_tramp_offset
undefined_tramp = /* ### undefined_tramp_offset-call_into_lisp_LRA*/ 0x140+call_into_lisp_LRA_page
undefined_tramp_offset:
        call_pal PAL_gentrap
	.long    10
        .byte    4
        .byte    23
        .byte    254
        .byte    238
        .byte    2
        .align 2
        .end    undefined_tramp


/*
 * The closure trampoline.
 */
        .text
        .globl  closure_tramp
        .ent    closure_tramp_offset
closure_tramp = /* ### */ 0x150 + call_into_lisp_LRA_page
closure_tramp_offset:
        ldl     reg_LEXENV, FDEFN_FUNCTION_OFFSET(reg_FDEFN)
        ldl     reg_L0, CLOSURE_FUNCTION_OFFSET(reg_LEXENV)
        addl    reg_L0, FUNCTION_CODE_OFFSET, reg_LIP
        jmp     reg_ZERO,(reg_LIP)
        .end    closure_tramp

	.text
	.globl	end_of_tramps
end_of_tramps:


/*
 * Function-end breakpoint magic.
 */

	.text
	.align	2
	.set	noreorder
	.globl	function_end_breakpoint_guts
function_end_breakpoint_guts:
	.word	type_ReturnPcHeader
	br	zero, function_end_breakpoint_trap
	nop
	mov	reg_CSP, reg_OCFP
	addl	reg_CSP, 4, reg_CSP
	addl	zero, 4, reg_NARGS
	mov	reg_NULL, reg_A1
	mov	reg_NULL, reg_A2
	mov	reg_NULL, reg_A3
	mov	reg_NULL, reg_A4
	mov	reg_NULL, reg_A5
1:

	.globl	function_end_breakpoint_trap
function_end_breakpoint_trap:
	call_pal PAL_gentrap
	.long	trap_FunctionEndBreakpoint
	br	zero, function_end_breakpoint_trap

	.globl	function_end_breakpoint_end
function_end_breakpoint_end:


