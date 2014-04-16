.section .text

.equ do_nothing, 0x0
.equ do_lev1,    0x4
.equ do_lev2,    0x3
.equ do_lev3,    0x2
.equ do_quit,    0x1

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
.globl do_menu_input
do_menu_input:
  push    {r4-r8, lr}

  input   .req    r0
  mask    .req    r3
  fb      .req    r4

  mov     fb,     r1        // Store framebuffer

  // Check for A-button input
  mov     mask,   #A

  and     r5,     input,mask// Test for A-button input
  cmp     r5,     #0
  bne     do_main_selection
  
  // Check for any movement commands
  mov     mask,   #UP 
  orr     mask,   #DOWN

  and     r5,     input, mask // Test for any D-Pad input
  cmp     r5,     #0
  bne     change_main_selection  // Branch to move_input

  mov     r0,     #do_nothing // Return do nothing
  b       do_menu_input_ret

do_main_selection:
  ldr     r6,     =main_selection // Get the selection
  ldrb    r2,     [r6]       // into r2

  mov     r0,     r2         // Return the correct status for what is selected
  b       do_menu_input_ret

change_main_selection:
  ldr     r6,     =main_selection // Get the selection
  ldrb    r2,     [r6]       // into r2
  mov     mask,   #UP
  and     r5,     input, mask// r5 = 0 when input is DOWN

  cmp     r5,     #0
  beq     change_down
  bne     change_up

change_down:
  cmp     r2,     #do_quit   // If r2 is quit
  moveq   r0,     #0         // just return
  beq     do_menu_input_ret
 
  sub     r2,     #1        // Move the cursor down    
  strb    r2,     [r6]

  mov     r0,     r2        // Redraw the cursor
  mov     r1,     fb
  bl      draw_menu_cursor

  mov     r0,     #do_nothing
  b       do_menu_input_ret

change_up:
  cmp     r2,     #do_lev1   // If r2 is lev1
  moveq   r0,     #0         // just return
  beq     do_menu_input_ret

  add     r2,     #1        // Move the cursor up
  strb    r2,     [r6]      

  mov     r0,     r2        // Redraw the cursor
  mov     r1,     fb
  bl      draw_menu_cursor

  mov     r0,     #do_nothing
  b       do_menu_input_ret

do_menu_input_ret:
  .unreq  input
  .unreq  mask
  .unreq  fb
  pop     {r4-r8, pc}

/*
 *  Draws the cursor at the necessary place.
 *    r0 - byte status
 *    r1 - int *fb_ptr
 */
draw_menu_cursor:
  push    {r4, r5, lr}

  // Clear the area over all cursor spots
  push    {r0,r1}
  mov     r0,   r1
  ldr     r1,   =34
  ldr     r2,   =280
  ldr     r3,   =84
  ldr     r4,   =500
  push    {r0-r4}
  bl      clear_area
  pop     {r0,r1}

  // Loop to determine the Y-coordinate of the cursor
  ldr     r2,   =283
  mov     r3,   r0
draw_menu_cursor_loop:
  add     r3,   #1
  cmp     r3,   #do_lev1
  bgt     draw_menu_cursor_next
  add     r2,   #52
  b       draw_menu_cursor_loop

  // Draw the cursor
draw_menu_cursor_next:
  mov     r0,   r1
  ldr     r1,   =34
  mov     r3,   #50
  mov     r4,   #50
  ldr     r5,   =cursor_img
  push    {r0-r5}
  bl      draw_img

  pop     {r4, r5, pc}

.section .data
.globl main_selection
main_selection: .byte 4
