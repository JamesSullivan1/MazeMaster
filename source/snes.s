.section .text

.equ md_in,         0b000
.equ md_out,        0b001
.equ LATCH,         9
.equ DATA,          10
.equ CLOCK,         11
.equ GPIO_SET_0,    0x2020001C
.equ GPIO_CLR_0,    0x20200028
.equ GPIO_LEV_0,    0x20200034
.equ CLO,           0x20003004

/*
 *  Set up the SNES controller for GPIO throughput.
 *
 */
.globl init_snes
init_snes:
  push    {lr}

  mov     r0,   #LATCH        // Pin 9 output
  mov     r1,   #md_out       // LATCH
  bl      set_gpio_md_n

  mov     r0,   #DATA         // Pin 10 input
  mov     r1,   #md_in        // DATA
  bl      set_gpio_md_n

  mov     r0,   #CLOCK        // Pin 11 output
  mov     r1,   #md_out       // CLOCK
  bl      set_gpio_md_n

  pop     {pc}

.globl read_snes
read_snes:
  push {r4, r5, lr}
	mov r0, #0 								// register sampling buttons 

	// write 1 to the clock line
 
	ldr r2, =0x2020001C					// base GPIO reg 
	mov r3, #1 
	lsl r3, #11 							// align bit for pin#11
	str r3, [r2] 						// GPSET0

	// write 1 to the latch line

	ldr r2, =0x2020001C 					// base GPIO reg 
	mov r3, #1 
	lsl r3, #9 								// align bit for pin#9
	str r3, [r2] 						// GPSET0

	// signal to SNES to sample buttons

  push {r0}
	mov	r0,	#12
	bl	wait
  pop {r0}

	// write 0 to the latch line

	ldr r2, =0x20200028 					// base GPIO reg 
	mov r3, #1 
	lsl r3, #9 								// align bit for pin#9
	str r3, [r2] 						// GPCLR0

	mov	r4,	#0

pulseLoop: 									// start pulsing to read from SNES 

	// wait 6 microseconds
	
  push {r0}
	mov	r0,	#6
	bl	wait
  pop {r0}

	// write 0 to the clock line
 
	ldr r2, =0x20200028 					// base GPIO reg 
	mov r3, #1 
	lsl r3, #11 							// align bit for pin#11
	str r3, [r2] 						// GPCLR0
	
	// wait 6 microseconds
	
  push {r0}
	mov	r0,	#6
	bl	wait
  pop {r0}
	
	// read bit i from the data line
	
	ldr r2, =0x20200034 					// base GPIO reg 
	ldr r1, [r2] 						// GPLEV0
	mov r3, #1 
	lsl r3, #10 							// align pin10 bit 
	and r1, r3 								// mask everything else 
	
	lsl	r0, #1								// move bits in r0 over to make room for bit i
	cmp r1, #0 
	orreq	r0, #1							// write 1 to r0 if button is pressed
	
	// write 1 to the clock line rising edge; new cycle
 
	ldr r2, =0x2020001C 					// base GPIO reg 
	mov r3, #1 
	lsl r3, #11 							// align bit for pin#11
	str r3, [r2] 						// GPSET0 
	
	add	r4, #1
	cmp	r4, #16
	blt	pulseLoop
  
  pop {r4, r5, pc}


/*
 *  Busy loop to wait for n microseconds (us)
 *      r0 <- int n
 */
.globl wait
wait:
  push    {lr}

  n       .req    r0
  clk     .req    r1
  clo_addr .req    r2

  ldr     clo_addr,     =CLO  // Address of Timer Ctr (Low)
  ldr     clk,    [clo_addr]  // Load the current time 
  add     n,      clk         // n += start
wait_loop:
  ldr     clk,    [clo_addr]  // Load the current time
  cmp     clk,    n           // Check time < (n + start) 
  blt     wait_loop           // Loop if so
  
  .unreq  n
  .unreq  clk
  .unreq  clo_addr

  pop     {pc}

