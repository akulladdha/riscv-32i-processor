//Hazard unit: detects the load-use hazard that forwarding cannot cover.
//A load's data is only available after MEM, so an instruction that needs it
//in EX immediately behind the load must wait one cycle.
//Purely combinational; the stall signal is acted on by the PC and the
//IF/ID and ID/EX registers in riscv_top.
module hazard_unit (
    input        id_ex_mem_read, //instruction in EX is a load
    input  [4:0] id_ex_rd,       //...and this is the register it loads
    input  [4:0] id_rs1,         //source-register fields of the instruction in ID
    input  [4:0] id_rs2,
    input        id_uses_rs1,    //...and whether those fields are real registers
    input        id_uses_rs2,    //   for this format (from control_unit)
    output       stall
);

    //Without the uses_* qualifiers, immediate bits that happen to sit in the
    //rs1/rs2 positions (I, U, J formats) cause false stalls. Those cost cycles
    //but never correctness; tests/progs/stallprec.s measures it.
    assign stall = id_ex_mem_read &&
                   (id_ex_rd != 5'b0) &&
                   ((id_uses_rs1 && id_ex_rd == id_rs1) ||
                    (id_uses_rs2 && id_ex_rd == id_rs2));

endmodule
