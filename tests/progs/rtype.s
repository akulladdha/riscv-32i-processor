# R-type ops the ALU never implemented: XOR SLL SRL SRA SLT SLTU.
# Also checks shift-amount masking (shamt must use only bits [4:0]).
    addi x1,  x0, 12        # 0b1100
    addi x2,  x0, 10        # 0b1010
    addi x8,  x0, 2
    addi x9,  x0, -16
    addi x16, x0, 33        # shift amount that must mask to 1
    xor  x3,  x1, x2        # 6
    sll  x4,  x1, x8        # 48
    srl  x5,  x1, x8        # 3
    sra  x10, x9, x8        # -4  (arithmetic)
    srl  x11, x9, x8        # 0x3FFFFFFC (logical)
    slt  x12, x9, x1        # 1   signed: -16 < 12
    sltu x13, x9, x1        # 0   unsigned: 0xFFFFFFF0 > 12
    slt  x14, x1, x9        # 0
    sltu x15, x1, x9        # 1
    sll  x17, x1, x16       # 12 << (33 & 31) = 24
    sub  x18, x1, x2        # 2   (these three were implemented but untested)
    and  x19, x1, x2        # 8
    or   x21, x1, x2        # 14
