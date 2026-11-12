# ECALL halts the core, precisely.
    addi x1, x0, 5
    addi x2, x0, 5
    beq  x1, x2, skip       # taken. When it resolves in EX, the ECALL below is
    ecall                   # already in ID: a wrong-path ECALL that is flushed.
    addi x3, x0, 99         # Halting from ID would stop here. Must NOT halt.
skip:
    addi x4, x0, 1
    addi x5, x0, 2          # older than the ECALL: must still complete (drain)
    ecall                   # the real halt
    addi x6, x0, 3          # younger than the ECALL: must never execute
    addi x7, x0, 4
