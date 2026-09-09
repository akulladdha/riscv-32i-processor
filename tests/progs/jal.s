# JAL: link register gets pc+4, PC redirects, and the two instructions
# already in flight are flushed. Currently a silent NOP.
    addi x1, x0, 1
    jal  x5, target     # x5 = 8 (pc 4 + 4); jump to 16
    addi x2, x0, 99     # flushed
    addi x3, x0, 99     # flushed
target:
    addi x4, x0, 7
