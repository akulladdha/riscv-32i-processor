# Flush depth, and two redirects back to back.
    addi x1, x0, 1
    beq  x0, x0, tgt        # always taken
    addi x2, x0, 99         # in ID  -> flushed
    addi x3, x0, 99         # in IF  -> flushed
tgt:
    addi x4, x0, 7          # must execute: flush must not kill 3
    addi x11, x0, 5
    addi x12, x0, 5
    beq  x11, x12, b2       # taken
    addi x13, x0, 99        # flushed
b2: beq  x11, x12, b3       # taken again, immediately
    addi x14, x0, 99        # flushed
b3: addi x15, x0, 1
