# Distance-3 RAW hazard: forwarding covers distance 1 and 2; distance 3
# relies on the register file returning write data in the same cycle.
    addi x1, x0, 5
    nop
    nop
    add  x5, x1, x0     # distance 3 from the producer
    add  x6, x1, x0     # distance 4 - control, must always work
