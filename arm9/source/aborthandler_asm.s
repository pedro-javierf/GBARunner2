.section .itcm
.altmacro

#include "consts.s"

//#define DEBUG_ABORT_ADDRESS

//when r15 is used as destination, problems will arise, as it's currently not supported

//BUG: problems arise when trying to read further than what's loaded from the rom in main memory with main memory addresses (for example when pc relative addressing is used)
//This bug makes it impossible to load the iwram in spongebob video pak = deadlock

.global data_abort_handler
data_abort_handler:
	//we assume r13_abt contains the address of the dtcm - 1 (0x04EFFFFF)
	//this makes it possible to use the bottom 16 bits for unlocking the memory protection

	//make use of the backwards compatible version
	//of the data rights register, so we can use 0xXXXXFFFF instead of 0x33333333
	mcr p15, 0, r13, c5, c0, 0

	//store the value of lr and update r13 to point to the top of the register list (place of r15)
	str lr, [r13, #(4 * 15 + 1)]!

	mrs lr, spsr
	movs lr, lr, lsl #27
	ldrcc pc, [r13, lr, lsr #25] //uses cpu_mode_switch_dtcm

data_abort_handler_thumb:
	msr cpsr_c, #0xD1
	ldr r12,= reg_table
	ldr r11, [r12, #(4 * 15)]
	ldrh r10, [r11, #-8]
	add r12, r12, #(address_thumb_table_dtcm - reg_table)
	ldr pc, [r12, r10, lsr #7]

.global data_abort_handler_arm_irq
data_abort_handler_arm_irq:
	str r0, [r13, #(-4 * 15)]
	sub r0, r13, #(4 * 14)
	msr cpsr_c, #0xD2
	stmia r0, {r1-r12,sp,lr}
	b data_abort_handler_cont

.global data_abort_handler_arm_svc
data_abort_handler_arm_svc:
	str r0, [r13, #(-4 * 15)]
	sub r0, r13, #(4 * 14)
	msr cpsr_c, #0xD3
	stmia r0, {r1-r12,sp,lr}
	b data_abort_handler_cont

.global data_abort_handler_arm_usr_sys
data_abort_handler_arm_usr_sys:
	stmdb r13, {r0-r14}^

data_abort_handler_cont:
	msr cpsr_c, #0xD1

	ldr r11,= reg_table
	//add r6, r5, #4	//pc+12
	//pc + 8
	//str r5, [r11, #(4 * 15)]
	ldr r10, [r11, #(4 * 15)]

	ldr r10, [r10, #-8]
	and r10, r10, #0x0FFFFFFF

	and r8, r10, #(0xF << 16)
	ldr r9, [r11, r8, lsr #14]

	ldr pc, [pc, r10, lsr #18]

	nop
.macro list_ldrh_strh_variant a,b,c,d,e
	.word ldrh_strh_address_calc_\a\b\c\d\e
.endm

.macro list_all_ldrh_strh_variants arg=0
	list_ldrh_strh_variant %((\arg>>4)&1),%((\arg>>3)&1),%((\arg>>2)&1),%((\arg>>1)&1),%((\arg>>0)&1)
.if \arg<0x1F
	list_all_ldrh_strh_variants %(\arg+1)
.endif
.endm
	list_all_ldrh_strh_variants

.rept 32
	.word address_calc_unknown
.endr

.macro list_ldr_str_variant a,b,c,d,e,f
	.word ldr_str_address_calc_\a\b\c\d\e\f
.endm

.altmacro
.macro list_all_ldr_str_variants arg=0
	list_ldr_str_variant %((\arg>>5)&1),%((\arg>>4)&1),%((\arg>>3)&1),%((\arg>>2)&1),%((\arg>>1)&1),%((\arg>>0)&1)
.if \arg<0x3F
	list_all_ldr_str_variants %(\arg+1)
.endif
.endm

	list_all_ldr_str_variants

.macro list_ldm_stm_variant a,b,c,d,e
	.word ldm_stm_address_calc_\a\b\c\d\e
.endm

.macro list_all_ldm_stm_variants arg=0
	list_ldm_stm_variant %((\arg>>4)&1),%((\arg>>3)&1),%((\arg>>2)&1),%((\arg>>1)&1),%((\arg>>0)&1)
.if \arg<0x1F
	list_all_ldm_stm_variants %(\arg+1)
.endif
.endm
	list_all_ldm_stm_variants
.rept 96
	.word address_calc_unknown
.endr

.global data_abort_handler_cont_finish
data_abort_handler_cont_finish:
	msr cpsr_fc, #0xD7

	mrs lr, spsr
	movs lr, lr, lsl #28

	bgt data_abort_handler_cont2
data_abort_handler_cont3:
	ldmdb r13, {r0-r14}^

	ldr lr,= pu_data_permissions
	mcr p15, 0, lr, c5, c0, 2

	//assume the dtcm is always accessible
	ldr lr, [r13], #(-4 * 15 - 1)

	subs pc, lr, #4

data_abort_handler_cont2:
	sub r12, r13, #(4 * 15)
	mov lr, lr, lsr #28
	orr lr, lr, #0xD0
	msr cpsr_c, lr
	ldmia r12, {r0-r14}
	msr cpsr_c, #0xD7

	ldr lr,= pu_data_permissions
	mcr p15, 0, lr, c5, c0, 2

	//assume the dtcm is always accessible
	ldr lr, [r13], #(-4 * 15 - 1)

	subs pc, lr, #4

//data_abort_handler_r15_dst:
//	pop {lr}
//	mov r0, lr
//	bl print_address
//	b .

//.global data_abort_handler_thumb_pc_tmp
//data_abort_handler_thumb_pc_tmp:
//	.word 0

.global address_calc_unknown
address_calc_unknown:
	ldr r0,= 0x06202000
	ldr r1,= 0x4B4E5541
	str r1, [r0]

	mov r0, r10
	ldr r1,= nibble_to_char
	ldr r12,= (0x06202000 + 32 * 10)
	//print address to bottom screen
	ldrb r2, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	ldrb r3, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	orr r2, r2, r3, lsl #8
	strh r2, [r12], #2

	ldrb r2, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	ldrb r3, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	orr r2, r2, r3, lsl #8
	strh r2, [r12], #2

	ldrb r2, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	ldrb r3, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	orr r2, r2, r3, lsl #8
	strh r2, [r12], #2

	ldrb r2, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	ldrb r3, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	orr r2, r2, r3, lsl #8
	strh r2, [r12], #2

	b .