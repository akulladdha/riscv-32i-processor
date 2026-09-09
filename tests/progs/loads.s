# Sub-word loads. funct3 is ignored in the memory path, so LB/LH/LBU/LHU
# all return the full word. Stores a known pattern first, then reads it back
# at byte and halfword granularity, covering sign- vs zero-extension.
    lui  x1, 0x87654
    addi x1, x1, 0x321      # 0x87654321
    addi x2, x0, 64         # base address
    sw   x1, 0(x2)
    lw   x3, 0(x2)          # 0x87654321
    lb   x4, 0(x2)          # 0x21 -> 0x00000021
    lb   x5, 3(x2)          # 0x87 -> sign-extend -> 0xFFFFFF87
    lbu  x6, 3(x2)          # 0x87 -> zero-extend -> 0x00000087
    lh   x7, 0(x2)          # 0x4321 -> 0x00004321
    lh   x8, 2(x2)          # 0x8765 -> sign-extend -> 0xFFFF8765
    lhu  x9, 2(x2)          # 0x8765 -> zero-extend -> 0x00008765
