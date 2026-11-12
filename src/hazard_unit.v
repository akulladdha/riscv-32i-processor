//Hazard unit: detects the load-use hazard that forwarding cannot cover.
//A load's data is only available after MEM, so an instruction that needs it
//in EX immediately behind the load must wait one cycle.
//Purely combinational; the stall signal is acted on by the PC and the
//IF/ID and ID/EX registers in riscv_top.
module hazard_unit (
    input        id_ex_mem_read, //instruction in EX is a load
    input  [4:0] id_ex_rd,       //...and this is the register it loads
    input  [4:0] id_rs1,         //source registers of the instruction in ID
    input  [4:0] id_rs2,
    output       stall
);

    //Known imprecision (Planned change D): id_rs1/id_rs2 are compared for every
    //instruction format, but for I/U/J types those bits are immediate bits.
    //A false match costs a cycle but never produces a wrong result.
    assign stall = id_ex_mem_read &&
                   (id_ex_rd != 5'b0) &&
                   ((id_ex_rd == id_rs1) || (id_ex_rd == id_rs2));

endmodule
