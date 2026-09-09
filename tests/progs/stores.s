# SB and SH. data_mem is word-only with no byte enables, so both execute as
# SW and clobber the whole word. Each block clears a word, writes two
# sub-word pieces at different offsets, then reads the word back.
    addi x2,  x0, 64
    sw   x0,  0(x2)         # clear
    addi x4,  x0, 0x77
    sb   x4,  0(x2)         # byte 0
    addi x5,  x0, 0x55
    sb   x5,  2(x2)         # byte 2
    lw   x6,  0(x2)         # expect 0x00550077

    addi x9,  x0, 68
    sw   x0,  0(x9)         # clear
    addi x10, x0, 0x123
    sh   x10, 0(x9)         # halfword low
    addi x11, x0, 0x456
    sh   x11, 2(x9)         # halfword high
    lw   x12, 0(x9)         # expect 0x04560123
