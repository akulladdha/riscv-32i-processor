# Forwarding paths, isolated by dependency distance.
    addi x1,  x0, 5
    addi x2,  x1, 3         # distance 1 -> EX/MEM forward. x2 = 8
    addi x4,  x0, 20
    nop
    addi x5,  x4, 5         # distance 2 -> MEM/WB forward. x5 = 25
    addi x6,  x0, 5         # older write to x6
    addi x6,  x0, 9         # newer write to x6
    add  x7,  x6, x0        # both sources match: EX/MEM must win. x7 = 9
    addi x8,  x0, 64
    addi x9,  x0, 42
    sw   x9,  0(x8)         # store data forwarded from distance 1
    lw   x10, 0(x8)         # x10 = 42
