.section .text

.equ do_nothing, 0x0
.equ do_restart, 0x1
.equ do_quit,    0x2

.equ B,       0b1000000000000000
.equ START,   0b0001000000000000
.equ UP,      0b0000100000000000
.equ DOWN,    0b0000010000000000
.equ LEFT,    0b0000001000000000
.equ RIGHT,   0b0000000100000000
.equ A,       0b0000000010000000

/*
 *  Executes the player's input
 *    r0 - half snes_input
 *    r1 - int *fb_ptr
 *  Returns:
 *    r0 - byte status
 */
.globl do_gameMenu_input
do_gameMenu_input:
  push    {r4-r8, lr}

  input   .req    r0
  mask    .req    r3
  fb      .req    r4

  mov     fb,     r1        // Store framebuffer

  // Check for A-button input
  mov     mask,   #A

  and     r5,     input,mask// Test for A-button input
  cmp     r5,     #0
  bne     do_selection
  
  // Check for any movement commands
  mov     mask,   #UP 
  orr     mask,   #DOWN

  and     r5,     input, mask // Test for any D-Pad input
  cmp     r5,     #0
  bne     change_selection  // Branch to move_input

  mov     r0,     #do_nothing // Return do nothing
  b       do_gameMenu_input_ret

do_selection:
  ldr     r6,     =selection // Get the selection
  ldrb    r2,     [r6]       // into r2

  mov     r0,     r2         // Return the correct status for what is selected
  b       do_gameMenu_input_ret

change_selection:
  ldr     r6,     =selection // Get the selection
  ldrb    r2,     [r6]       // into r2
  mov     mask,   #UP
  and     r5,     input, mask// r5 = 0 when input is DOWN

  cmp     r5,     #0
  beq     change_down
  bne     change_up

change_down:
  cmp     r2,     #do_restart// If r2 is quit
  movne   r0,     #0         // just return
  bne     do_gameMenu_input_ret
 
  mov     r2,     #do_quit   // Change selection
  strb    r2,     [r6]       // to 'quit'

  mov     r0,     r2        // Redraw the cursor
  mov     r1,     fb
  bl      draw_cursor

  mov     r0,     #do_nothing
  b       do_gameMenu_input_ret

change_up:
  cmp     r2,     #do_quit   // If r2 is restart
  movne   r0,     #0         // just return
  bne     do_gameMenu_input_ret

  mov     r2,     #do_restart// Change selection
  strb    r2,     [r6]       // to 'restart'

  mov     r0,     r2        // Redraw the cursor
  mov     r1,     fb
  bl      draw_cursor

  mov     r0,     #do_nothing
  b       do_gameMenu_input_ret

do_gameMenu_input_ret:
  .unreq  input
  .unreq  mask
  .unreq  fb
  pop     {r4-r8, pc}

/*
 *  Draws the cursor at the necessary place.
 *    r0 - byte status
 *    r1 - int *fb_ptr
 */
draw_cursor:
  push    {r4, r5, lr}

  cmp     r0, #do_quit
  bne     erase_bottom

// Erase the upper cursor position
erase_top:
  push    {r0,r1}
  mov     r0,   r1
  ldr     r1,   =426
  ldr     r2,   =335
  ldr     r3,   =476
  ldr     r4,   =385
  push    {r0-r4}
  bl      clear_area
  pop     {r0,r1}

  b       draw_cursor_next  

// Erase the lower cursor position
erase_bottom:  
  push    {r0,r1}
  mov     r0,   r1
  ldr     r1,   =438
  ldr     r2,   =383
  ldr     r3,   =488
  ldr     r4,   =433
  push    {r0-r4}
  bl      clear_area
  pop     {r0,r1}

// Draw the cursor at the correct coordinates
draw_cursor_next:
  cmp     r0,   #do_restart
  mov     r0,   r1
  ldreq   r1,   =426
  ldrne   r1,   =438
  ldreq   r2,   =335
  ldrne   r2,   =383
  mov     r3,   #50
  mov     r4,   #50
  ldr     r5,   =cursor_img
  push    {r0-r5}
  bl      draw_img

  pop     {r4, r5, pc}

.section .data
.globl selection
selection: .byte 1
