# Load-use interlock, with an ALU consumer and with a branch consumer.
    addi x1, x0, 64
    addi x2, x0, 7
    sw   x2, 0(x1)
    lw   x3, 0(x1)          # load
    addi x4, x3, 1          # immediately dependent -> must stall. x4 = 8
    lw   x7, 0(x1)          # load again
    beq  x7, x2, hit        # branch immediately dependent on the load
    addi x5, x0, 99         # flushed if the branch resolved correctly
hit:
    addi x6, x0, 1
