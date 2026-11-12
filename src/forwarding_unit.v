`default_nettype none
//Forwarding unit: for each EX-stage source register, decide whether its value
//should come from the register file (00), from MEM/WB (01), or from EX/MEM (10).
//Purely combinational.
module forwarding_unit (
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,
    input  wire [4:0] ex_mem_rd,
    input  wire ex_mem_reg_write,
    input  wire [4:0] mem_wb_rd,
    input  wire mem_wb_reg_write,
    output wire [1:0] forward_a,
    output wire [1:0] forward_b
);

    localparam FWD_NONE   = 2'b00; //use the value read from the register file
    localparam FWD_MEM_WB = 2'b01; //result produced 2 instructions earlier
    localparam FWD_EX_MEM = 2'b10; //result produced 1 instruction earlier

    //The same selection logic is needed for both operands. A function lets us
    //write it once; each call below elaborates into its OWN copy of the
    //hardware (two sets of comparators), exactly as the duplicated code did.
    //
    //EX/MEM is checked first: if both later stages write the same register,
    //the younger instruction (EX/MEM) holds the newer value and must win.
    //rd == 0 is excluded because x0 is never really written.
    //
    //Every signal the function reads is passed as an argument. A continuous
    //assign that calls a function re-evaluates only when an ARGUMENT changes,
    //so a function that reads module signals directly simulates stale values
    //while synthesizing correctly - a simulation/synthesis mismatch.
    function [1:0] select;
        input [4:0] rs;
        input [4:0] em_rd;
        input em_we;
        input [4:0] mw_rd;
        input mw_we;
        begin
            if      (em_we && em_rd != 5'b0 && em_rd == rs) select = FWD_EX_MEM;
            else if (mw_we && mw_rd != 5'b0 && mw_rd == rs) select = FWD_MEM_WB;
            else                                            select = FWD_NONE;
        end
    endfunction

    assign forward_a = select(id_ex_rs1, ex_mem_rd, ex_mem_reg_write, mem_wb_rd, mem_wb_reg_write);
    assign forward_b = select(id_ex_rs2, ex_mem_rd, ex_mem_reg_write, mem_wb_rd, mem_wb_reg_write);

endmodule

`default_nettype wire
