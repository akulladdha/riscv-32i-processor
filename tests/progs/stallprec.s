# Load-use stall precision. Each load is followed by an instruction whose
# register-specifier BITS happen to match the load's rd, but which does not
# actually read that register. Only the final pair is a real dependency.
# Correct hardware stalls exactly once.
    addi x9, x0, 7
    sw   x9, 0(x0)          # mem[0] = 7

    lw   x1, 0(x0)
    addi x5, x0, 1          # imm[4:0] = 1 sits in the rs2 field -> looks like x1
                            # ADDI has no rs2: must NOT stall
    lw   x2, 0(x0)
    lui  x6, 0x10           # imm bit 16 sits in the rs1 field [19:15] -> looks like x2
                            # LUI has no rs1: must NOT stall
    lw   x4, 0(x0)
    add  x8, x4, x0         # real dependency on x4: MUST stall. x8 = 7

    addi x10, x0, 99        # end marker
