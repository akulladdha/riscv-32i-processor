# JALR: register-relative jump with the computed address's LSB forced to 0.
# The LSB clear is observable through a following JAL's link value: landing
# at 29 instead of 28 would make that link 33 rather than 32.
    addi x1,  x0, 24        # even target
    addi x7,  x0, 29        # ODD target - must be cleared to 28
    jalr x5,  x1, 0         # link 12, jump to 24
    addi x2,  x0, 99        # flushed
    addi x3,  x0, 99        # flushed
    addi x6,  x0, 55        # never fetched
    jalr x8,  x7, 0         # at 24: link 28, jump to 29 & ~1 = 28
    jal  x10, done          # at 28: link must be 32, proving pc == 28
    addi x11, x0, 77        # flushed
    addi x12, x0, 77        # flushed
done:
    addi x4,  x0, 7
