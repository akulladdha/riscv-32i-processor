# FENCE is architecturally a NOP on a single-hart, in-order, cacheless core.
# It must retire without writing a register or disturbing the pipeline.
    addi x1, x0, 5
    fence
    addi x2, x0, 6
    fence
    add  x3, x1, x2         # 11
