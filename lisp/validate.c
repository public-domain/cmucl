/*
 * $Header: validate.c,v 1.4 93/04/28 01:58:43 wlott Exp $
 *
 * Memory Validation
 */

#include <stdio.h>
#include "lisp.h"
#include "os.h"
#include "globals.h"
#include "validate.h"

static void ensure_space(lispobj *start, unsigned long size)
{
    if(os_validate((os_vm_address_t)start,(os_vm_size_t)size)==NULL){
	fprintf(stderr,
		"ensure_space: Failed to validate %ld bytes at 0x%08X\n",
		size,
		(unsigned long)start);
	exit(1);
    }
}

#ifdef HOLES

static os_vm_address_t holes[] = HOLES;

static void make_holes(void)
{
    int i;

    for (i = 0; i < sizeof(holes)/sizeof(holes[0]); i++) {
	if (os_validate(holes[i], HOLE_SIZE) == NULL) {
	    fprintf(stderr,
		    "ensure_space: Failed to validate %ld bytes at 0x%08X\n",
		    HOLE_SIZE,
		    (unsigned long)holes[i]);
	    exit(1);
	}
	os_protect(holes[i], HOLE_SIZE, 0);
    }
}
#endif

void validate(void)
{
#ifdef PRINTNOISE
	printf("Validating memory ...");
	fflush(stdout);
#endif

	/* Read-Only Space */
	read_only_space = (lispobj *) READ_ONLY_SPACE_START;
	ensure_space(read_only_space, READ_ONLY_SPACE_SIZE);

	/* Static Space */
	static_space = (lispobj *) STATIC_SPACE_START;
	ensure_space(static_space, STATIC_SPACE_SIZE);

	/* Dynamic-0 Space */
	dynamic_0_space = (lispobj *) DYNAMIC_0_SPACE_START;
	ensure_space(dynamic_0_space, DYNAMIC_SPACE_SIZE);

	current_dynamic_space = dynamic_0_space;

	/* Dynamic-1 Space */
	dynamic_1_space = (lispobj *) DYNAMIC_1_SPACE_START;
	ensure_space(dynamic_1_space, DYNAMIC_SPACE_SIZE);

	/* Control Stack */
	control_stack = (lispobj *) CONTROL_STACK_START;
	ensure_space(control_stack, CONTROL_STACK_SIZE);

	/* Binding Stack */
	binding_stack = (lispobj *) BINDING_STACK_START;
	ensure_space(binding_stack, BINDING_STACK_SIZE);

#ifdef HOLES
	make_holes();
#endif

#ifdef PRINTNOISE
	printf(" done.\n");
#endif
}
