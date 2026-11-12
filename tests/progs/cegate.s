# Clock-enable test program: a little of everything stateful - a loop with
# forwarding and taken/not-taken branches, a store and load, a load-use stall,
# a call and return, and a halt. Run with ce always 1 and with ce random;
# the final architectural state must be identical.
    addi x1, x0, 0
    addi x2, x0, 1
    addi x5, x0, 10         # iterations
loop:
    add  x3, x1, x2
    addi x1, x2, 0
    addi x2, x3, 0
    addi x5, x5, -1
    bne  x5, x0, loop       # x2 ends as fib(11) = 89
    sw   x2, 64(x0)
    lw   x10, 64(x0)        # 89
    addi x11, x10, 1        # load-use stall: 90
    jal  x12, fn
    addi x14, x0, 7
    ecall
fn:
    addi x13, x0, 5
    jalr x0, x12, 0
