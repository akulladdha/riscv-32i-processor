# An unknown opcode halts the core and raises the error flag, instead of
# silently executing as a NOP.
    addi x1, x0, 1
    .word 0xFFFFFFFF        # opcode 1111111: not an RV32I instruction
    addi x2, x0, 2          # must never execute
