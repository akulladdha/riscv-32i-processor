# x0 must be hardwired: writes discarded, reads always zero.
    addi x0, x0, 99         # discarded
    add  x1, x0, x0         # 0
    lui  x0, 0x12345        # discarded
    add  x2, x0, x0         # 0
    addi x3, x0, 7
    add  x0, x3, x3         # discarded even with a real value
    add  x4, x0, x0         # 0
