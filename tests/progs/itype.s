# I-type ALU ops. The decoder forced alu_op=00 ("force add") for opcode
# 0010011, so all of these executed as ADDI.
    addi  x1,  x0, 12
    addi  x2,  x0, -16
    xori  x3,  x1, 10       # 6
    ori   x4,  x1, 3        # 15
    andi  x5,  x1, 10       # 8
    slti  x6,  x2, 0        # 1   signed: -16 < 0
    slti  x7,  x1, 0        # 0
    sltiu x8,  x1, 100      # 1
    sltiu x9,  x2, 100      # 0   unsigned: 0xFFFFFFF0 > 100
    slli  x10, x1, 2        # 48
    srli  x11, x1, 2        # 3
    srai  x12, x2, 2        # -4
    srli  x13, x2, 2        # 0x3FFFFFFC
