.section .text

/*
 *  Returns a pointer to a char buffer containing the ascii values of the integer
 *    r0 - int i
 *  Return:
 *    r0 - char[] *value
 */
.globl itoa
itoa:
  push    {r4, r5, r6, r7, lr}
  i       .req    r0
  mod     .req    r5
  ascii   .req    r6

  cmp     i,      #0      // assert i is positive or 0
  blt     itoa_ret 

  mov     mod,    #10     // modulo = 10
  ldr     ascii,  =intChar// intChar buffer
div_loop:
  mov     r1,     #10     // r1 = modulo for subroutine
  bl      int_div         // r0 = quo, r1 = rem 
  add     r1,     #48     // remainder += 48 for ascii val
  strb    r1,     [ascii], #1 // Store the ascii value of the digit
  cmp     i,      #0      // Check if i >= 0
  bgt     div_loop

div_loop_end:
  ldr     r0,     =intChar// intChar buffer for return

  ldr     r4,     =intChar// Base of char buffer
  mov     r7,     #0      // Counter
push_rev_array:
  ldrb    r2,     [r4], #1// Load the first ascii value
  cmp     r2,     #0      // While next != 0
  beq     push_rev_array_end
  add     r7,     #1      // Increment counter
  push    {r2}            // Push onto the stack
  b       push_rev_array
push_rev_array_end:  
  ldr     r4,     =intChar// Base of char buffer
pop_rev_array:
  subs    r7,     #1      // While r7 > 0
  blt     pop_rev_array_end
  pop     {r2}
  strb    r2,     [r4], #1// Store back into array
  b       pop_rev_array
pop_rev_array_end:
  ldr     r0,     =intChar// Pointer to char array for return

itoa_ret:
  .unreq  i
  .unreq  mod
  .unreq  ascii
  pop     {r4, r5, r6, r7, pc}


/*
 * Computes q = a/b with remainder r. Requires that a > b.
 *    r0 - int a
 *    r1 - int b
 * Returns:
 *    r0 - int quotient
 *    r1 - int remainder
 */
.globl int_div
int_div:
  push    {lr}
  a       .req    r0
  bI      .req    r1

  mov     r2,     #0      // Store the quotient count
subLoop:  
  cmp     a,      bI      // while a >= b
  subge   a,      bI      // a -= b
  addge   r2,     #1      // quotient += 1
  bge     subLoop

  mov     r1,     r0      // r1 = remainder
  mov     r0,     r2      // r0 = quotient

  .unreq  a
  .unreq  bI
  pop     {pc}
