# All six branch types, each in its should-branch or should-not-branch
# direction. control_unit ignores funct3, so every one behaves as BEQ.
# A "1" in the guarded register means the branch fell through.
    addi x1, x0, 5
    addi x2, x0, 7
    addi x3, x0, -3         # 0xFFFFFFFD: negative signed, huge unsigned
    bne  x1, x2, l1         # TAKEN   5 != 7
    addi x10, x0, 1
l1: beq  x1, x2, l2         # not taken
    addi x11, x0, 1
l2: blt  x3, x1, l3         # TAKEN   -3 < 5 signed
    addi x12, x0, 1
l3: bltu x3, x1, l4         # not taken  0xFFFFFFFD > 5 unsigned
    addi x13, x0, 1
l4: bge  x1, x3, l5         # TAKEN   5 >= -3 signed
    addi x14, x0, 1
l5: bgeu x3, x1, l6         # TAKEN   0xFFFFFFFD >= 5 unsigned
    addi x15, x0, 1
l6: addi x20, x0, 99        # sentinel: execution reached the end
