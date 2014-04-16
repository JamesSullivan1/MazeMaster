.section .text

.equ  plyr,   0x01
.equ  wall,   0x02
.equ  key,    0x08
.equ  door,   0x04
.equ  exit,   0x05
.equ  end,    0x06

.equ  g_tl_x, 256
.equ  g_tl_y, 128

.equ B,       0b1000000000000000
.equ START,   0b0001000000000000
.equ UP,      0b0000100000000000
.equ DOWN,    0b0000010000000000
.equ LEFT,    0b0000001000000000
.equ RIGHT,   0b0000000100000000
.equ A,       0b0000000010000000

.equ do_lev1, 0x4
.equ do_lev2, 0x3
.equ do_lev2, 0x2

/*
 *  Initializes the game grid with a preset maze and returns a pointer to the grid, as well as the starting location.
 *    r0 - int level_num
 *  Returns: 
 *    r0 - grid *grid_address
 *    r1 - cell *player_loc
 */
.globl initialize
initialize:
    push    {r4, r5, r6, lr}

    addr    .req    r0
    inAddr  .req    r1
    levl    .req    r3
    ctr     .req    r4
    plyr    .req    r6

    mov     levl,   r0
    
    ldr     addr,   =grid
    cmp     levl,   #do_lev1
    ldreq   inAddr, =lev1Grid
    cmp     levl,   #do_lev2
    ldreq   inAddr, =lev2Grid
    cmp     levl,   #do_lev3
    ldreq   inAddr, =lev3Grid

    mov     r5,     addr          // Save base addr
    mov     r2,     #16
    mov     ctr,    r2, lsl #4    // Top of counter 
    sub     ctr,    #1            //  is at 16*16 - 1

put_loop:
    ldrb    r2,     [inAddr], #1  // get next byte in lev1Grid
    strb    r2,     [addr],   #1  // And store into the grid

    cmp     r2,     #plyr         // If the (last) cell contains the player
    subeq   plyr,   addr, #1      // Store into r6 for later

    subs    ctr,    #1            // Decrement counter
    bge     put_loop

    mov     addr,   r5            // Restore base addr
    mov     r1,     plyr          // And set player ptr
    
    .unreq  addr
    .unreq  inAddr
    .unreq  levl
    .unreq  ctr
    .unreq  plyr

    pop     {r4, r5, r6, pc}


/*
 *  Executes the player's input given the SNES input.
 *    r0 - cell *player_address
 *    r1 - half snes_input
 *    r2 - int *fb_ptr
 *  Returns:
 *    r0 - cell *player_address
 *    r1 - boolean hasWon
 */
.globl do_input
do_input:
  push    {r4-r8, lr}
  pAdr    .req    r0
  input   .req    r1
  mask    .req    r3
  oAdr    .req    r4
  nAdr    .req    r6
  fb      .req    r7
  won     .req    r8

  mov     fb,     r2        // Store framebuffer

  // Check for A-button input
  mov     mask,   #A

  and     r5,     input,mask// Test for A-button input
  cmp     r5,     #0
  bne     open_door_input   // Door opening
  
  // Check for any movement commands
  mov     mask,   #UP 
  orr     mask,   #DOWN
  orr     mask,   #LEFT
  orr     mask,   #RIGHT

  and     r5,     input, mask // Test for any D-Pad input
  cmp     r5,     #0
  bne     move_input        // Branch to move_input

  b       do_input_ret

move_input:
  mov     oAdr,   r0        // Store player address
  push    {r1}              // Store snes input
  bl      move              // Call move subroutine
  mov     won,    r1        // Store won flag for later
  pop     {r1}              // Restore snes input
  mov     nAdr,   r0        // Store the new player address

  cmp     nAdr,   oAdr      // Check if the player actually moved
  beq     do_input_ret

  // Redraw the relevant tiles
  mov     r2,     fb        // r2 = fb for subroutine
  push    {r1}              // Store input on stack
  bl      redraw_tile       // Draw the old tile
  pop     {r1}              // Restore input

  mov     r2,     fb        // r2 = fb for subroutine
  mov     r0,     oAdr      // r0 = new tile addr for subroutine
  bl      redraw_tile       // Draw the new tile

  mov     r0,     nAdr      // r0 points to new tile for return

  // Update the step/key count
  push    {r0}
  mov     r0,     fb        // fb to r0 for function call
  bl      draw_keys_steps
  pop     {r0}

  b       do_input_ret

open_door_input:
  mov     oAdr,   r0        // Store player address
  push    {r1}              // Store snes input
  bl      open_door         // Call open_door subroutine
  mov     nAdr,   r1        // Store the target door address
  pop     {r1}              // Restore snes input

  cmp     nAdr,   #0        // If the new address is nonzero then redraw
  movne   r0,     nAdr
  movne   r2,     fb        // frame buffer in r2 for subroutine call
  blne    redraw_tile       // Draw the new tile

  mov     r0,     oAdr      // r0 points to the player's old loc for return

  // Update the step/key count
  push    {r0}
  mov     r0,     fb        // fb to r0 for function call
  bl      draw_keys_steps
  pop     {r0}

do_input_ret:
  mov     r1,     won
  .unreq  pAdr
  .unreq  input
  .unreq  oAdr
  .unreq  nAdr
  .unreq  mask
  .unreq  fb
  .unreq  won
  pop     {r4-r8, pc}

/*
 *  Redraws the tile at the given address
 *    r0 - cell *player_address
 *    r2 - int *fb_ptr
 */
.globl redraw_tile
redraw_tile:
  push    {r4, r5, lr}
  cAdr    .req    r0
  fb      .req    r2
  tile    .req    r4

  mov     r5,     fb        // save fb_ptr

  mov     r1,     cAdr      // r1 = cell addr
  ldrb    r4,     [cAdr]    // r4 = value of cell
  mov     r0,     r4        // into r0 for function call

  push    {r1}              // Save cell address
  bl      get_tile_img      // r0 = tile_img ptr
  pop     {r1}              // Restore cell address

  mov     tile,   r0        // Save tile_img 
  ldr     r0,     =grid     // r0 = base grid addr
  bl      get_cell_coordinate 

  // r0 = x, r1 = y
  mov     r2,     r1        // y in r2
  mov     r1,     r0        // x in r1
  mov     r0,     r5        // fb_ptr in r0
  mov     r3,     r4        // tile_img in r3
  bl      Draw32_32_tile    // Draw the new tile

  .unreq  cAdr
  .unreq  fb
  .unreq  tile
  pop     {r4, r5, pc}

/*
 *  Returns the adjacent cell in the desired direction, if possible.
 *      r0 - cell *address
 *      r1 - half snes_input
 *  Returns:
 *      r0 - cell *adj_address (0 if not in the grid)
 */
.globl get_adj_cell
get_adj_cell:
  push    {lr}
  cell    .req    r0
  drct    .req    r1
  grid    .req    r2
  cellSz  .req    r3

  ldr     grid,   =grid

  mov     cellSz, #1

  cmp     drct,   #UP             // If direction is UP
  subeq   r0,     cellSz, lsl #4  // Get the address of the cell above
  beq     get_adj_cell_ret

  cmp     drct,   #RIGHT          // If direction is RIGHT
  addeq   r0,     cellSz          // Get the address of the cell to the right
  beq     get_adj_cell_ret

  cmp     drct,   #DOWN           // If direction is DOWN
  addeq   r0,     cellSz, lsl #4  // Get the address of the cell below
  beq     get_adj_cell_ret

  cmp     drct,   #LEFT           // If direction is LEFT
  subeq   r0,     cellSz          // Get the address of the cell to the left
  beq     get_adj_cell_ret


  .unreq  drct

  mov     r0,     #0              // Otherwise, set r0 to 0
  pop     {pc}

get_adj_cell_ret:
  push    {r4}
  subs    r4,     cell, grid      // r4 = cell - grid
  movlt   r0,     #0              // r0 = 0 if r4 < 0
  poplt   {r4}
  poplt   {pc}                

  add     r4,     grid, cellSz, lsl #8 // r4 = edge_of_grid*
  cmp     r4,     cell            // r0 = 0 if cell* > r4
  movlt   r0,     #0
  popgt   {r4}
  popgt   {pc}

  .unreq  cell
  .unreq  grid

  pop     {r4, pc} 

/*
 *  Returns an adjacent door or exit door, if possible.
 *      r0 - cell *player_address
 *  Returns:
 *      r0 - cell *door_address (0 if no adjacent door exists)
 */
.globl get_adj_door
get_adj_door:
  push    {lr}
  pCel    .req    r0
  dCel    .req    r1

  mov     dCel,   #0          // Default value is 0

  // Check above
  ldrb    r2,     [pCel, #-16]
  cmp     r2,     #door       // If cell = door
  subeq   dCel,   pCel, #16   // store that address
  beq     get_adj_door_ret    // and return
  cmp     r2,     #exit       // And similar for exit doors
  subeq   dCel,   pCel, #16
  beq     get_adj_door_ret
  // Check right
  ldrb    r2,     [pCel, #1]
  cmp     r2,     #door       // If cell = door
  addeq   dCel,   pCel, #1   // store that address
  beq     get_adj_door_ret    // and return
  cmp     r2,     #exit       // And similar for exit doors
  addeq   dCel,   pCel, #1
  beq     get_adj_door_ret
  // Check below
  ldrb    r2,     [pCel, #16]
  cmp     r2,     #door       // If cell = door
  addeq   dCel,   pCel, #16   // store that address
  beq     get_adj_door_ret    // and return
  cmp     r2,     #exit       // And similar for exit doors
  addeq   dCel,   pCel, #16
  beq     get_adj_door_ret
  // Check above
  ldrb    r2,     [pCel, #-1]
  cmp     r2,     #door       // If cell = door
  subeq   dCel,   pCel, #1    // store that address
  beq     get_adj_door_ret    // and return
  cmp     r2,     #exit       // And similar for exit doors
  subeq   dCel,   pCel, #1

get_adj_door_ret:
  mov     r0,     dCel        // dCel for return
  .unreq  pCel
  .unreq  dCel
  pop     {pc}

/*
 *  Returns the physical address for a tile of the given cell type.
 *    Input: r0 <- byte tile
 *    Returns: r0 <- tile *address
 */
.globl get_tile_img
get_tile_img:
  push    {lr}
  cmp     r0,     #plyr       // Player
  ldreq   r0,     =player_img  
  beq     tile_img_ret
  cmp     r0,     #wall       // Wall
  ldreq   r0,     =wall_img
  beq     tile_img_ret
  cmp     r0,     #door       // Door
  ldreq   r0,     =door_img
  beq     tile_img_ret
  cmp     r0,     #exit       // Exit
  ldreq   r0,     =exit_img
  beq     tile_img_ret
  cmp     r0,     #key        // Key
  ldreq   r0,     =key_img
  beq     tile_img_ret
  cmp     r0,     #0          // Floor
  ldreq   r0,     =floor_img
  beq     tile_img_ret
  cmp     r0,     #6          // End-floor
  ldreq   r0,     =floor_img
tile_img_ret:
  pop     {pc}


/* 
 *  Converts a cell's raw address to (x,y) format on the frame buffer
 *    r0 <- grid *grid_addr
 *    r1 <- cell *cell_addr
 *  Returns:
 *    r0 <- int x
 *    r1 <- int y
 */
.globl get_cell_coordinate
get_cell_coordinate:
  push  {lr}

  grid  .req  r0
  cell  .req  r1
  y     .req  r3

  mov   y,    #0

  sub   cell, grid    // Get cell_addr - grid_addr
loop:
  cmp   cell, #16     // While cell >= 16
  addge y,    #1      // Increment y 
  subge cell, #16     // cell -= 16
  bge   loop

  mov   r0,   cell    // Leftover = x in r0
  mov   r1,   y       // y in r1

  mov   r0,   r0, lsl#5 // r0 << 5
  mov   r1,   r1, lsl#5 // r1 << 5

  add   r0,   #g_tl_x   // upper left of grid
  add   r1,   #g_tl_y   // upper left of grid  

  .unreq grid
  .unreq cell
  .unreq y

  pop   {pc}

.section .data
/* Defines area in memory for a 16 * 16 grid of cells,
 * each of which consists of a byte for flags.
 *         0: hasPlayer
 *         1: isWall
 *         2: hasDoor
 *         3: hasKey
 *         4: n/a
 *         5: n/a
 *         6: n/a
 *         7: n/a 
 * Accessing cell (n,m):
 *  load [grid_address 
 *           + n << 3
 *           + m << 7]
*/
.align    0
grid:
  .rept   16*16
    .byte 0
  .endr
.align    4

// 0x00: Floor
// 0x01: Player
// 0x02: Wall
// 0x04: Door
// 0x08: Key
// 0x05: Exit
lev1Grid:
  .ascii "\2\2\2\2\2\2\2\2\2\2\2\2\2\2\2\2"
  .ascii "\2\0\0\0\0\0\0\0\4\0\0\0\0\0\0\2"
  .ascii "\2\0\2\2\2\0\2\0\2\2\2\2\2\2\0\2"
  .ascii "\2\0\2\8\2\0\2\0\2\0\0\0\0\2\0\2"
  .ascii "\2\0\2\0\2\0\2\0\4\0\2\0\0\2\0\2"
  .ascii "\2\0\2\0\2\0\2\0\2\0\2\0\0\2\0\2"  
  .ascii "\2\0\0\0\0\0\2\0\2\0\2\0\0\2\0\2"
  .ascii "\2\2\2\2\2\2\2\4\2\0\2\0\2\2\0\2"
  .ascii "\2\8\0\0\0\0\2\0\2\0\2\0\4\0\0\2"
  .ascii "\2\2\2\2\2\0\2\0\2\0\2\0\2\2\2\2"
  .ascii "\2\0\0\0\0\0\2\0\2\0\2\0\0\0\0\2"
  .ascii "\2\0\2\2\2\2\2\0\2\0\2\2\2\2\0\2"
  .ascii "\2\0\0\0\0\0\0\0\2\0\0\0\0\2\0\2"
  .ascii "\2\2\2\2\2\2\2\0\2\2\2\2\0\2\0\2"
  .ascii "\2\1\0\0\0\0\0\0\2\8\0\0\0\2\0\2"
  .ascii "\2\2\2\2\2\2\2\2\2\2\2\2\2\2\5\2"

lev2Grid:
  .ascii "\2\2\2\2\2\2\2\5\2\2\2\2\2\2\2\2"
  .ascii "\2\0\0\0\0\0\2\0\4\0\0\0\0\0\0\2"
  .ascii "\2\0\2\2\2\0\2\2\2\2\2\2\2\2\0\2"
  .ascii "\2\0\2\8\2\0\2\0\2\0\0\0\0\2\0\2"
  .ascii "\2\0\2\0\0\0\2\0\4\0\2\0\0\2\0\2"
  .ascii "\2\0\2\0\2\2\2\0\2\0\2\0\0\2\0\2"  
  .ascii "\2\0\0\0\2\8\0\0\2\0\2\0\0\2\0\2"
  .ascii "\2\0\2\2\2\2\2\0\2\0\2\0\2\2\0\2"
  .ascii "\2\0\0\0\0\0\2\0\2\0\2\0\4\0\0\2"
  .ascii "\2\0\2\2\2\2\2\0\2\0\2\0\2\2\2\2"
  .ascii "\2\0\0\0\0\0\0\0\2\0\2\0\0\0\0\2"
  .ascii "\2\0\2\2\2\2\2\0\2\0\2\2\2\2\0\2"
  .ascii "\2\0\0\0\0\0\2\0\2\0\0\0\0\2\0\2"
  .ascii "\2\0\2\2\2\2\2\0\2\2\2\2\0\2\2\2"
  .ascii "\2\1\2\0\0\0\0\0\0\0\0\0\0\0\8\2"
  .ascii "\2\2\2\2\2\2\2\2\2\2\2\2\2\2\2\2"

lev3Grid:
  .ascii "\2\2\2\2\2\2\2\2\2\2\2\2\2\2\2\2"
  .ascii "\2\0\0\0\0\0\0\0\4\8\0\0\0\0\0\2"
  .ascii "\2\0\2\0\2\0\2\0\2\2\2\2\2\2\0\2"
  .ascii "\2\0\2\2\2\0\2\0\0\0\0\0\0\2\0\2"
  .ascii "\2\0\2\0\2\2\2\0\4\0\2\0\0\2\0\2"
  .ascii "\2\0\2\0\2\0\2\0\2\0\2\0\0\2\0\2"  
  .ascii "\2\0\0\0\0\0\0\0\2\0\2\0\0\2\0\2"
  .ascii "\2\0\2\2\2\2\2\0\2\0\2\0\2\2\0\2"
  .ascii "\2\0\0\0\0\0\2\4\2\0\2\0\0\0\0\2"
  .ascii "\2\0\2\2\2\0\2\0\2\0\2\0\2\2\2\2"
  .ascii "\2\0\2\8\0\0\2\0\2\0\2\0\0\0\0\2"
  .ascii "\2\0\2\2\2\2\2\0\2\0\2\2\2\2\0\2"
  .ascii "\2\0\2\0\0\0\0\0\2\0\0\0\0\2\0\2"
  .ascii "\2\0\2\2\4\2\2\2\2\2\2\2\0\2\0\2"
  .ascii "\2\1\2\0\0\2\0\0\2\8\0\0\0\2\0\2"
  .ascii "\2\2\2\5\2\2\2\2\2\2\2\2\2\2\2\2"


.align
 
