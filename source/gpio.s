.section .text

.equ GPIO_FSEL_0,   0x20200000
.equ GPIO_SET_0,    0x2020001C
.equ GPIO_CLR_0,    0x20200028
.equ GPIO_LEV_0,    0x20200034
.equ CLO,           0x20003004

/*
 *  Sets GPIO Line n to the given mode.
 *      r0 <- int pin_n
 *      r1 <- byte mode
 */
.globl set_gpio_md_n
set_gpio_md_n:
  push    {lr}

  n       .req    r0
  mode    .req    r1
  fsel    .req    r2

  cmp     n,    #0            // Assert n >= 0
  blt     set_gpio_md_ret
  cmp     n,    #54           // Assert n <= 53
  bge     set_gpio_md_ret

  mov     fsel, #0

get_reg_num:
  cmp     n,    #10           // Subtract 10 from n until below 10
  subge   n,    #10
  addge   fsel, #4            // Increment register offset by 4
  bge     get_reg_num   

  add     n,    n, lsl#1      // n = 3n for pin offset
  mov     mode, mode, lsl n   // Shift mode by correct offset

  ldr     r3,   =GPIO_FSEL_0  // FSEL Base register
  add     fsel, r3            // Incremented by offset
  ldr     r0,   [fsel]
  mov     r3,   #0b111        // Set bit clear mask up
  mov     r3,   r3,     lsl n
  bic     r0,   r3            // Bit clear the correct 3 bits

  .unreq  n

  orr     r0,   mode          // And-mask in mode 
  str     r0,   [fsel]

  .unreq  mode
  .unreq  fsel

set_gpio_md_ret:
  pop     {pc}

/*
 *   Sets or clears a GPIO line
 *      r0 <- int n
 *      r1 <- boolean hi/low
 */
.globl set_clr_gpio_n
set_clr_gpio_n:
  push    {lr}

  n       .req    r0
  op      .req    r1
  addr    .req    r2

  cmp     n,      #0          // Assert n >= 0
  blt     set_clr_gpio_ret
  cmp     n,      #54         // Assert n <= 53
  bge     set_clr_gpio_ret

  cmp     op,     #1          // if op = 1, we are setting a line
  ldreq   addr,   =GPIO_SET_0 
  ldrne   addr,   =GPIO_CLR_0

  .unreq  op

  cmp     n,      #32         // if n >= 32, subtract 32 from n
  addge   addr,   #4          // and add 4 to the reg address
  subge   n,      #32

  ldr     r1,     [addr]      // Get GPIO_SET/CLR_n

  mov     r3,     #0b1        // Set bit mask up
  mov     r3,     r3, lsl n
  orr     r1,     r3          // And set the appropriate bit

  str     r1,     [addr]

  .unreq  n
  .unreq  addr
  
set_clr_gpio_ret:
  pop     {pc}

/*
 *    Reads the GPIO line n
 *        r0 <- int n
 *    Returns:
 *        r0 <- boolean line_data
 */
.globl read_gpio_n
read_gpio_n:
  push    {lr}

  n       .req    r0
  addr    .req    r1

  cmp     n,      #0          // Assert n >= 0
  blt     read_gpio_ret
  cmp     n,      #54         // Assert n <= 53
  bge     read_gpio_ret

  ldr     addr,   =GPIO_LEV_0 // Base GPIO_LEV address

  cmp     n,      #32         // if n >= 32, subtract 32 from n
  addge   addr,   #4          // and add 4 to the reg address
  subge   n,      #32

  ldr     r2,     [addr]      // Get GPIO_LEV register

  mov     r3,     #0b1        // Set bit mask up
  mov     r3,     r3, lsl n
  and     r0,     r3          // Get bit n in the register into r0

  .unreq  n
  .unreq  addr
 
read_gpio_ret:
  pop     {pc}
