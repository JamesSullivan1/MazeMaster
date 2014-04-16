.section    .init
.globl     _start


.equ B,       0b1000000000000000
.equ START,   0b0001000000000000
.equ UP,      0b0000100000000000
.equ DOWN,    0b0000010000000000
.equ LEFT,    0b0000001000000000
.equ RIGHT,   0b0000000100000000
.equ A,       0b0000000010000000

.equ do_nothing, 0x0
.equ do_restart, 0x1
.equ do_quit_pause,    0x2

.equ do_lev1,    0x4
.equ do_lev2,    0x3
.equ do_lev3,    0x2
.equ do_quit_main,    0x1


_start:
    b       main
    
.section .text

main:
  mov     sp, #0x8000

  bl		EnableJTAG
  bl    init_snes
	bl		InitFrameBuffer

  // Branch to haltLoop on initialization error
	cmp		r0, #0
	beq		haltLoop$

  fb    .req    r4
  mov   fb, r0        // Store fb_ptr in fb
  push    {r1}              // Save cell address

main_menu:
  // Set default cursor selection to top
  ldr     r1,     =main_selection 
  mov     r0,     #do_lev1
  strb    r0,     [r1] 
  
  // Draw the black background box
  push    {fb}
  mov     r0,     fb
  ldr     r1,     =0
  ldr     r2,     =0
  ldr     r3,     =1024
  ldr     fb,     =768
  push    {r0-fb}
  bl      clear_area
  pop     {fb}
  
  // Draw the main screen background
  push    {r0-r5}
  mov     r0,   fb
  mov     r1,   #0
  mov     r2,   #0
  ldr     r3,   =1024
  ldr     fb,   =768
  ldr     r5,   =menu_img
  push    {r0-r5}
  bl      draw_img
  pop     {r0-r5}

  // Draw the cursor
  push    {r0-r5}
  mov     r0,   fb
  ldr     r1,   =34
  ldr     r2,   =283
  mov     r3,   #50
  mov     fb,   #50
  ldr     r5,   =cursor_img
  push    {r0-r5}
  bl      draw_img
  pop     {r0-r5}

main_menu_pretest:
  bl    read_snes       // Wait for no input
  cmp   r0, #0
  bne   main_menu_pretest
  ldr   r0, =10000
  bl     wait
main_menu_loop:
  bl    read_snes       // Get snes input

  mov   r1, fb
  bl    do_menu_input

  cmp   r0, #do_nothing
  beq   main_menu_test

  cmp   r0, #do_lev1
  beq   game_start
  cmp   r0, #do_lev2
  beq   game_start
  cmp   r0, #do_lev3
  beq   game_start

  cmp   r0, #do_quit_main
  beq   quit

main_menu_test:
  bl    read_snes       // Wait for no input
  cmp   r0, #0
  bne   main_menu_test

  ldr   r0, =10000
  bl     wait
  b     main_menu_loop
 
  grid    .req    r5
  plyr    .req    r6

game_start:
  mov     r9,     r0    // Store level number

  // Clean up the screen
  push    {fb}
  mov     r0,     fb
  ldr     r1,     =0
  ldr     r2,     =0
  ldr     r3,     =1024
  ldr     fb,     =768
  push    {r0-fb}
  bl      clear_area
  pop     {fb}

  mov   r0, r9        // Level number for subroutine
  bl    initialize
  mov   grid, r0      // Store grid_ptr in r5 
  mov   plyr, r1      // Store player_cell_ptr in r6


  // Set default steps to 150
  mov   r0, #150
  ldr   r1, =numSteps
  str   r0, [r1]

  // Set default keys to 0
  mov   r0, #0
  ldr   r1, =numKeys
  str   r0, [r1]


  // Draw the grid
  mov   r0, fb
  mov   r1, grid
  bl    draw_grid

  // Draw the steps, keys label
  mov   r0, fb
  mov   r1, #256
  mov   r2, #112
  ldr   r3, =keys_str
  bl    draw_string

  mov   r0, fb
  mov   r1, #256
  mov   r2, #96
  ldr   r3, =steps_str
  bl    draw_string

  // Draw the number of steps, keys
  mov   r0,  fb
  bl    draw_keys_steps
/* Todo draw a pause menu

*/
playLoop:
  ldr   r1,   =numSteps // Check if the player has any steps
  ldr   r0,   [r1]
  cmp   r0,   #0
  ble   gameOver

  bl    read_snes       // Get snes input
  mov   r1, #START      // If input is START
  and   r1, r0
  cmp   r1, #0
  bne   pause           // Pause the game
  mov   r1, r0
  mov   r0, plyr
  mov   r2, fb
  bl    do_input
  mov   plyr, r0  
  cmp   r1, #1          // Check if the player won
  beq   gameWon

playLoopTest:
  bl    read_snes       // Wait for no input
  cmp   r0, #0
  bne   playLoopTest

  ldr   r0, =10000
  bl     wait

  b     playLoop

pause:
    // Set default cursor selection to top
  ldr     r1,     =selection 
  mov     r0,     #do_restart
  strb    r0,     [r1] 

  mov   r0, fb
  bl    draw_pause

pauseLoopPretest:
  bl    read_snes       // Wait for no input
  cmp   r0, #0
  bne   pauseLoopPretest
  ldr   r0, =10000
  bl     wait
pauseLoop:
  bl    read_snes       // Get snes input
  mov   r1, #START      // If input is START
  and   r1, r0          // End the pause loop
  cmp   r1, #0
  bne   pauseLoopEnd

  mov   r1, fb
  bl    do_gameMenu_input

  cmp   r0, #do_nothing
  beq   pauseLoopTest

  cmp   r0, #do_restart
  beq   game_start

  cmp   r0, #do_quit_pause
  beq   main_menu

pauseLoopTest:
  bl    read_snes       // Wait for no input
  cmp   r0, #0
  bne   pauseLoopTest
  ldr   r0, =10000
  bl     wait
  b     pauseLoop
pauseLoopEnd:
  mov   r0, fb
  mov   r1, grid
  bl    draw_grid
  b     playLoop

  .unreq grid
  .unreq plyr

haltLoop$:
	b		haltLoop$

quit:
  // Draw the black background box
  push    {fb}
  mov     r0,     fb
  ldr     r1,     =0
  ldr     r2,     =0
  ldr     r3,     =1024
  ldr     fb,     =768
  push    {r0-fb}
  bl      clear_area
  pop     {fb}
  b       haltLoop$

.globl gameOver
gameOver:
  // Draw the black background box
  push    {fb}
  mov     r0,     fb
  ldr     r1,     =384
  ldr     r2,     =256
  ldr     r3,     =640
  ldr     fb,     =512
  push    {r0-fb}
  bl      clear_area
  pop     {fb}

  mov   r0, fb
  ldr   r1, =480
  ldr   r2, =352
  ldr   r3, =fail_str
  bl    draw_string

  b     gameEnd

.globl gameWon
gameWon:
  // Draw the black background box
  push    {fb}
  mov     r0,     fb
  ldr     r1,     =384
  ldr     r2,     =256
  ldr     r3,     =640
  ldr     fb,     =512
  push    {r0-fb}
  bl      clear_area
  pop     {fb}

  mov   r0, fb
  ldr   r1,     =460
  ldr   r2,     =352
  ldr   r3, =won_str
  bl    draw_string

  b     gameEnd
    
gameEnd:

  ldr   r0, =1000000
  bl    wait

  mov   r0, fb
  ldr   r1,     =448
  ldr   r2,     =480
  ldr   r3, =end_str
  bl    draw_string

gameEndLoop:
  bl    read_snes       // Wait for no input
  cmp   r0, #0
  bne   gameEndLoopNext
  ldr   r0, =10000
  bl     wait
  b     gameEndLoop
gameEndLoopNext:
  bl    read_snes       // Wait for some input
  cmp   r0, #0
  bne   main_menu     
  ldr   r0, =10000
  bl     wait
  b     gameEndLoopNext
  

  .unreq fb

.section .data
keys_str: .asciz "KEYS: "
steps_str:.asciz "STEPS: "
won_str:.asciz "YOU'RE WINNER"
fail_str:.asciz "YOU LOSE"
end_str: .asciz "Press any button"
.globl pause_restart
pause_restart: .asciz "RESTART"
.globl pause_quit
pause_quit: .asciz "QUIT"
.globl pause_str
pause_str: .asciz "~~PAUSED~~"
.align

