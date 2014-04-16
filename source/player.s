.section .text

.equ  hasP,   0x01
.equ  wall,   0x02
.equ  key,    0x08
.equ  door,   0x04
.equ  exit,   0x05
.equ  end,    0x06

/*
 *  Move the player by one cell, if it is a legal movement.
 *    r0 - cell *player_address
 *    r1 - half snes_input
 *  Returns: 
 *    r0 - cell *player_address  
 *    r1 - boolean hasWon
 */
.globl  move
move:
  push    {r4, r5, r7, lr}
  pAdr    .req    r0
  nAdr    .req    r1
  pCel    .req    r2
  nCel    .req    r3
  keys    .req    r4

  mov     r7,     #0        // isWon = 0

  push    {r0}
  bl      get_adj_cell      // Get the address of the target cell
  mov     nAdr,   r0        // And store into nAdr
  pop     {r0}

  cmp     nAdr,   #0        // 0 indicates the cell was out of bounds
  beq     move_ret          // so terminate subroutine execution


  ldrb    pCel,   [pAdr]    // Get the state of the player cell
  cmp     pCel,   #hasP     // Assert that the player is in the cell
  bne     move_ret          

  ldrb    nCel,   [nAdr]    // Get the state of the new cell
  cmp     nCel,   #end      // If the cell is the end, then set a win flag
  moveq   r7,     #1

  ldrb    nCel,   [nAdr]    // Get the state of the new cell
  cmp     nCel,   #wall     // Assert that the new cell is not a wall
  beq     move_ret

  cmp     nCel,   #door     // Assert the new cell is not a door
  beq     move_ret 
  cmp     nCel,   #exit     // Or an exit door
  beq     move_ret
  
  cmp     nCel,   #key      // Check if the player is picking up a key
  ldreq   r5,      =numKeys // Address of player's keys
  ldreq   keys,    [r5]     // Get the number of available keys
  addeq   keys,   #1        // Add a key to the inventory
  streq   keys,   [r5]

move_cont:
  tmp     .req    r5
  mov     tmp,    #0        // tmp = 0 (floor cell flags)
  strb    tmp,    [pAdr]    // Set the old cell to empty
  .unreq  tmp

  mov     pAdr,   nAdr      // Set player address to new one for return
  strb    pCel,   [pAdr]    // And store the player at the new cell

  ldr     r5,     =numSteps // Load the address of numSteps
  ldr     r4,     [r5]      // And get this value
  sub     r4,     #1        // Decrement by 1
  str     r4,     [r5]      // Store back into numSteps

move_ret:
  .unreq  pAdr
  .unreq  nAdr
  .unreq  pCel
  .unreq  nCel
  .unreq  keys
  mov     r1,     r7        // Victory flag in r1
  pop     {r4, r5, r7, pc}

/*
 *  Open a door adjacent to the player, if they have any keys.
 *    r0 - cell *player_address
 *  Returns: 
 *    r0 - cell *player_address  
 *    r1 - cell *door_address (0 if no door opened)
 */
.globl open_door
open_door:
  push    {r4, r5, lr}
  pAdr    .req    r0
  dAdr    .req    r1
  keys    .req    r3

  push    {r0}
  bl      get_adj_door      // Get an adjacent door
  mov     dAdr,   r0        // Store the return value into dAdr
  pop     {r0}

  cmp     dAdr,   #0        // if dAdr = 0, no door exists so return
  beq     open_door_ret

  ldr     r2,     =numKeys  // Address of player's keys
  ldr     keys,   [r2]      // Get the number of available keys

  cmp     keys,   #0        // Assert player has keys to use
  movle   dAdr,   #0        // If not, set dAdr to 0 for return
  ble     open_door_ret

  ldrb    r4,     [dAdr]    // Load the value of the door
  cmp     r4,     #exit     // If it is an exit door
  moveq   r4,     #end      // Then it will be set to an end cell
  movne   r4,     #0        // If not then set to floor

  sub     keys,   #1
  ldr     r5,     =numKeys
  str     keys,   [r5]      // Remove key from player inventory

  strb    r4,     [dAdr]    // Rewrite the cell value
open_door_ret:
  .unreq  pAdr
  .unreq  dAdr
  .unreq  keys
  pop     {r4, r5, pc}

.section  .data
// How many keys the player has
.globl numKeys
numKeys:
  .word   0
.align 

// How many steps the player has
.globl numSteps
numSteps:
  .word   150
.align
