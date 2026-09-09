# LUI and AUIPC. Both currently hit the decoder's empty default and
# execute as NOPs, so every destination stays 0.
    lui   x1, 0x12345       # 0x12345000
    lui   x2, 0xFFFFF       # 0xFFFFF000
    auipc x3, 0             # pc(8)  + 0      = 8
    auipc x4, 1             # pc(12) + 0x1000 = 0x100C
    addi  x5, x1, 273       # 0x12345000 + 0x111 = 0x12345111
