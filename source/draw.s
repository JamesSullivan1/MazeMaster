.section .text

.equ      WHT,    0xFFFF
.equ      BLK,    0x0
.equ      g_tl_x, 256
.equ      g_tl_y, 128
.equ      k_tl_x, 296
.equ      k_tl_y, 112
.equ      s_tl_x, 304
.equ      s_tl_y, 96


/* Draw Pixel to a 1024x768x16bpp frame buffer
 * Note: no bounds checking on the (X, Y) coordinate
 *	r0 - frame buffer pointer
 *	r1 - pixel X coord
 *	r2 - pixel Y coord
 *	r3 - colour (use low half-word)
 */
.global DrawPixel16bpp
DrawPixel16bpp:
	  push	{r4, lr}

    // Assert that (x,y) are in (0..1023, 0..768)
    cmp     r1,     #0
    blt     DrawPixel16bpp_end
    ldr     r4,     =1024
    cmp     r1,     r4
    bge     DrawPixel16bpp_end
    cmp     r2,     #0
    blt     DrawPixel16bpp_end
    ldr     r4,     =768
    cmp     r2,     r4
    bge     DrawPixel16bpp_end

	offset	.req	r4

	  // offset = (y * 1024) + x = x + (y << 10)
	  add		offset,	r1, r2, lsl #10
	  // offset *= 2 (for 16 bits per pixel = 2 bytes per pixel)
	  lsl		offset, #1

	  // store the colour (half word) at framebuffer pointer + offset
	  strh	r3,		[r0, offset]
DrawPixel16bpp_end:
  .unreq offset
  pop		{r4, pc}

/*
 *  Draws an arbitrary w*h image at (x,y) (top left corner of image)
 *    sp+20  - int *fb_ptr
 *    sp+16  - int x
 *    sp+12  - int y
 *    sp+8   - int width
 *    sp+4   - int height
 *    sp     - int *img_ptr
 *
 */
.globl draw_img
draw_img:
    pop     {r0-r5}                 // Recover the input from stack
    push    {r4-r7, lr}

    mov     r7,  r5                 // Store img ptr   

    push    {r0-r3}
    bl      in_bounds               // Terminate if x,y out of bounds
    cmp     r0,       #0
    popeq   {r0-r3}
    popeq   {r4-r7, pc}
    pop     {r0-r3}
    
    // Assert that (w,h) are in (1..1024, 1..768)
    cmp     r3,     #1
    blt     draw_img_ret
    ldr     r5,     =1024
    cmp     r3,     r5
    bgt     draw_img_ret
    cmp     r2,     #1
    blt     draw_img_ret
    ldr     r5,     =768
    cmp     r4,     r5
    bgt     draw_img_ret


    fb      .req    r0
    x       .req    r1
    y       .req    r2
    w       .req    r3
    h       .req    r4
    xCtr    .req    r5
    yCtr    .req    r6   
    img     .req    r7

    mov     xCtr,  w
    mov     yCtr,  h

draw_img_loop:
    cmp     yCtr,     #0              // While yCtr >= 0
    ble     draw_img_ret
draw_img_loop_x:
    subs    xCtr,     #1              // If xCtr < 0
    movlt   xCtr,     w               // Reset xCtr value
    sublt   x,        xCtr            // x -= xCtr to reset
    sublt   yCtr,     #1              // Decrement yCtr
    addlt   y,        #1              // Increment y
    blt     draw_img_loop

    ldrh    r4,     [img],     #2     // Load next pixel (and increment)
    push    {r0-r3}
    mov     r3,     r4
    bl      DrawPixel16bpp            // And draw it on buffer
    pop     {r0-r3}

    add     x,        #1              // Increment x

    b       draw_img_loop

draw_img_ret:
    .unreq  fb
    .unreq  x
    .unreq  y
    .unreq  w
    .unreq  h
    .unreq  xCtr
    .unreq  yCtr
    .unreq  img

    pop     {r4-r7, pc}


/* Draw a 32x32 pixel tile at the selected (x,y) coordinate
 * where (x,y) indicates the top-left corner of the tile
 *	r0 - int *fb_ptr
 *	r1 - int x
 *	r2 - int y
 *	r3 - tile *tile_ptr
 */
.globl Draw32_32_tile
Draw32_32_tile:
    push    {r4, r5, r6, lr}

    push    {r0-r3}
    bl      in_bounds               // Terminate if x,y out of bounds
    cmp     r0,       #0
    popeq   {r0-r3}
    popeq   {r4-r6, pc}
    pop     {r0-r3}

    sub     sp,     #4              // Allocate bytes on stack

    fb      .req    r0
    x       .req    r1
    y       .req    r2
    px      .req    r3
    tile    .req    r4
    x_ctr   .req    r5
    y_ctr   .req    r6

    mov     x_ctr,  #32
    mov     y_ctr,  #32
    mov     tile,   r3

    str     x,      [sp]            // Save x on stack 

loop_x:
    ldrh    px,     [tile],     #2  // Load next pixel (and increment)
    push    {fb, x, y, px}
    bl      DrawPixel16bpp          // And draw it on buffer
    pop     {fb, x, y, px}
    subs    x_ctr,  #1              // if x_ctr > 0
    addne   x,      #1              // increment x
    bne     loop_x
loop_y:
    subs    y_ctr,  #1              // if y_ctr > 0
    movne   x_ctr,  #32             // Reset x counter
    ldrne   x,      [sp]            // Reset value of x
    addne   y,      #1              // And decrement y by 1
    bne     loop_x

    .unreq  fb
    .unreq  x
    .unreq  y
    .unreq  px
    .unreq  tile
    .unreq  x_ctr
    .unreq  y_ctr

    add     sp,     #4              // Deallocate stack 
    pop     {r4, r5, r6, pc}

/* 
 *  Draws the entire 16x16 grid onto the center of the screen.
 *  Input:
 *    r0 - int *fb_ptr
 *    r1 - grid *grid_addr
 */
.globl draw_grid
draw_grid:
    push    {r4, r5, r6, lr}

    fb_ptr  .req      r0
    grid    .req      r1
    x_ctr   .req      r2
    y_ctr   .req      r3
    x       .req      r4
    y       .req      r5
    cell    .req      r6

    mov     x_ctr,    #0
    mov     y_ctr,    #0
    mov     x,        #g_tl_x     // Upper left of grid
    mov     y,        #g_tl_y 
grid_loop:
    ldrb    cell,     [grid], #1  // Get the next cell

    push    {r0}
    mov     r0,       cell        // Move cell to r0 for call
    bl      get_tile_img          // Get ptr to tile image
    mov     cell,     r0
    pop     {r0}

    push    {r0-r3}
    mov     r1,       x           // Set variables for draw subroutine
    mov     r2,       y
    mov     r3,       cell
    bl      Draw32_32_tile
    pop     {r0-r3}

    add     x_ctr,    #1          // Increment counter
    cmp     x_ctr,    #16         // while x_ctr < 16
    addlt   x,        #32         // increment x coordinate
    blt     grid_loop             // and loop again

    mov     x_ctr,    #0          // Reset x_ctr
    mov     x,        #g_tl_x     // And x coordinate
    add     y_ctr,    #1
    cmp     y_ctr,    #16         // while y_ctr < 16
    addlt   y,        #32         // increment y coordinate
    blt     grid_loop             // Loop again
    
    .unreq  fb_ptr
    .unreq  grid
    .unreq  x_ctr
    .unreq  y_ctr
    .unreq  x
    .unreq  y
    .unreq  cell
    pop     {r4, r5, r6, pc}

/*
 *  Draws a 8x16 ASCII character from an ASCII-arranged font bitmap at the desired (x,y)
 *  Based on the upper-left position of the character
 *    r0 - int *fb_ptr
 *    r1 - int x
 *    r2 - int y
 *    r3 - char ascii_val
 */
 draw_char:
    push    {r4-r7, lr}

    fb_ptr  .req      r0
    x       .req      r1
    y       .req      r2
    char    .req      r3
    char_ptr .req     r4
    x_ctr   .req      r5
    y_ctr   .req      r6

    // Base address for ascii character bitmap
    ldr     char_ptr, =font 
    mov     r7,       #16
    mla     char_ptr, char,  r7,  char_ptr

    mov     x_ctr,    #8
    mov     y_ctr,    #16
char_loop:
    cmp     y_ctr,    #0              // End if y_ctr = 0
    beq     draw_char_ret
    ldrb    char,     [char_ptr], #1  // Load the next byte
    mov     r7,       #1
char_loop_x:
    subs    x_ctr,    #1              // If x_ctr < 0
    sublt   x,        #8              // And reset x
    movlt   x_ctr,    #8              // Reset x_ctr
    addlt   y,        #1              // Increment y
    sublt   y_ctr,    #1              // Decrement y_ctr
    blt     char_loop                 // Loop again

    tst     char,     r7              // Test the appropriate bit
    mov     r7,       r7, lsl #1 
    addeq   x,        #1              // If 0, no need to draw bit
    beq     char_loop_x

    push    {r0-r3}
    ldr     r3,       =WHT            // White pixel
    bl      DrawPixel16bpp
    pop     {r0-r3}
    add     x,        #1              // Increment x
    b       char_loop_x               // Loop again

    .unreq  fb_ptr
    .unreq  x
    .unreq  y
    .unreq  char
    .unreq  char_ptr
    .unreq  x_ctr
    .unreq  y_ctr

draw_char_ret:
    pop     {r4-r7, pc}



/* 
 *  Draws a null-terminated string of ASCII characters at (x,y) [upper left measured] using draw_char
 *    r0 - int *fb_ptr
 *    r1 - int x
 *    r2 - int y
 *    r3 - char[] *str_ptr
 */
 .globl draw_string
 draw_string:
    push    {r4, lr}

    push    {r0-r2}
    bl      in_bounds                 // Terminate if x,y out of bounds
    cmp     r0,       #0
    popeq   {r0-r2}
    popeq   {r4, pc}
    pop     {r0-r2}
      
    fb_ptr  .req      r0
    x       .req      r1
    y       .req      r2
    char    .req      r3
    strn    .req      r4
      
    mov     strn,      char
string_loop:
    ldrb    char,     [strn], #1      // Load the next ASCII char
    cmp     char,     #0              // If it is 0, terminate
    beq     draw_string_ret
      
    push    {r0-r3}
    bl      draw_char                 // Write next character
    pop     {r0-r3}
    add     x,        #8              // Increment x
    b       string_loop
  
    .unreq  fb_ptr
    .unreq  x
    .unreq  y
    .unreq  strn
draw_string_ret:
    pop     {r4, pc}

/*
 * Draws the number of keys and steps the player has available.
 *   r0 - int *fb_ptr
 */
.globl draw_keys_steps
draw_keys_steps:
    push    {r4, lr}
    fb      .req    r0
    keys    .req    r1
    steps   .req    r2
    a_buf   .req    r4

// Draw the number of keys

    push    {r0-r4}
    mov     r1,     #k_tl_x          // Upper left x of key
    mov     r2,     #k_tl_y          // Upper left y of key
    add     r3,     r1, #16          // x' = x + 16
    add     r4,     r2, #16          // y' = y + 16
    push    {r0-r4}
    bl      clear_area               // Clear the defined area
    pop     {r0-r4}

    ldr     r1,     =numKeys
    ldr     keys,   [r1]             // Get the number of keys

    push    {r0-r2}
    mov     r0,     keys
    bl      itoa                     // r0 = char[] *buf
    mov     a_buf,  r0               // Store ptr
    pop     {r0-r2}

    push    {r0-r3}
    mov     r1,     #k_tl_x           // Upper left
    mov     r2,     #k_tl_y           // x and y
    mov     r3,     a_buf             // ascii buffer
    bl      draw_string 
wipe_key_loop:
    ldrb    r0,     [r4]              // Load the next byte
    cmp     r0,     #0
    movne   r0,     #0
    strne   r0,     [r4], #1          // Wipe and post-increment
    bne     wipe_key_loop
    pop     {r0-r3}

// Draw the number of steps

    push    {r0-r4}
    mov     r1,     #s_tl_x          // Upper left x of steps
    mov     r2,     #s_tl_y          // Upper left y of steps
    add     r3,     r1, #24          // x' = x + 16
    add     r4,     r2, #16          // y' = y + 16
    push    {r0-r4}
    bl      clear_area               // Clear the defined area
    pop     {r0-r4}

    ldr     r1,     =numSteps
    ldr     steps,  [r1]             // Get the number of steps

    push    {r0-r2}
    mov     r0,     steps
    bl      itoa                     // r0 = char[] *buf
    mov     a_buf,  r0               // Store ptr
    pop     {r0-r2}

    push    {r0-r3}
    mov     r1,     #s_tl_x           // Upper left
    mov     r2,     #s_tl_y           // x and y
    mov     r3,     a_buf             // ascii buffer
    bl      draw_string 
wipe_step_loop:
    ldrb    r0,     [r4]              // Load the next byte
    cmp     r0,     #0
    movne   r0,     #0
    strne   r0,     [r4], #1          // Wipe and post-increment
    bne     wipe_step_loop
    pop     {r0-r3}
  
    .unreq  fb
    .unreq  keys
    .unreq  steps
    pop     {r4, pc}

/*
 *  Clears all of the pixels from (x,y) to (x', y')
 *    sp     - int *fb_ptr
 *    sp-4   - int x
 *    sp-8   - int y
 *    sp-12  - int x'
 *    sp-16  - int y'
 * 
 */
.globl clear_area
clear_area:
    pop     {r0 - r4}                 // Get input values
    push    {r5, r6, lr}

    subs    r3,     r1                // x' -= x
    blt     clear_area_ret            // if dX < 0 return
      
    subs    r4,     r2                // y' -= y
    blt     clear_area_ret            // if dY < 0 return

    x       .req    r1
    y       .req    r2
    xCtr    .req    r3
    yCtr    .req    r4

    mov     r6,     xCtr              // Save xCtr

clear_loop:
    cmp     yCtr,     #0              // While yCtr >= 0
    blt     clear_area_ret
clear_loop_x:
    subs    xCtr,     #1              // If xCtr < 0
    movlt   xCtr,     r6              // Reset xCtr value
    sublt   x,        xCtr            // x -= xCtr to reset
    sublt   yCtr,     #1              // Decrement yCtr
    addlt   y,        #1              // Increment y
    blt     clear_loop

    push    {r3}
    mov     r3,       #BLK            // Draw a black px at (x,y)
    bl      DrawPixel16bpp
    pop     {r3}

    add     x,        #1              // Increment x

    b       clear_loop
    
clear_area_ret:
    .unreq  x
    .unreq  y
    .unreq  xCtr
    .unreq  yCtr
    pop     {r5, r6, pc}

/*
 *  Draws the entire pause menu onto the screen
 *    r0 - int *fb_ptr
 */
.globl draw_pause
draw_pause:
    push    {r4, r5, lr}
  
    mov     r5,      r0              // Save the fb ptr
    // Draw the black background box
    ldr     r1,     =384
    ldr     r2,     =256
    ldr     r3,     =640
    ldr     r4,     =512
    push    {r0-r4}
    bl      clear_area

    // Write the labels
    mov     r0,     r5
    ldr     r1,     =472
    ldr     r2,     =266
    ldr     r3,     =pause_str
    bl      draw_string

    mov     r0,     r5
    ldr     r1,     =484
    ldr     r2,     =352
    ldr     r3,     =pause_restart
    bl      draw_string

    mov     r0,     r5
    ldr     r1,     =496
    ldr     r2,     =400
    ldr     r3,     =pause_quit
    bl      draw_string

    // Draw the cursor left of RESTART
    push    {r4, r5}
    mov     r0,     r5
    ldr     r1,     =426
    ldr     r2,     =335
    ldr     r3,     =50
    ldr     r4,     =50
    ldr     r5,     =cursor_img
    push    {r0-r5}
    bl      draw_img
    pop     {r4, r5}

    pop     {r4, r5, pc}

/* 
 *    Returns 0 if the (x,y) is out of bounds
 *    Input:
 *      r1 - int x
 *      r2 - int y
 *    Return:
 *      r0 - boolean in_bounds
 *      
 */
in_bounds:
    push    {lr}

    cmp     r1,     #0                // 0 <= x <= 1023   
    blt     not_ib
    ldr     r0,     =1024
    cmp     r1,     r0
    bge     not_ib
    cmp     r2,     #0                // 0 <= y <= 767
    blt     not_ib
    ldr     r0,     =768
    cmp     r2,     r0
    bge     not_ib

    mov     r0,     #1
    pop     {pc}

not_ib:
    mov     r0,     #0
    pop     {pc}


.section .data
font:       .incbin "font.bin"
// Enough room for a 32 bit integer ascii string
.globl intChar
intChar:
  .rept 32
  .byte 0
  .endr
.align

