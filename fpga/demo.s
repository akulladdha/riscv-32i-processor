# Board demo. Computes fib(11) = 89 = 0x59 with a loop, stores it to memory,
# loads it back into x10, and halts.
#
# On the board: sw[4:0] = 01010 (x10) shows 0059 when done; led[15] (halted)
# lights; led[14] (error) stays off. With sw[15] on it takes ~6 s, and
# led[7:0] shows the PC walking through the loop.
    addi x1, x0, 0
    addi x2, x0, 1
    addi x5, x0, 10         # iterations
loop:
    add  x3, x1, x2
    addi x1, x2, 0
    addi x2, x3, 0
    addi x5, x5, -1
    bne  x5, x0, loop
    sw   x2, 64(x0)
    lw   x10, 64(x0)        # x10 = 89 = 0x59
    ecall                   # clean halt: led[15] on, led[14] off
