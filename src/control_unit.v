`default_nettype none
module control_unit(
    input  wire [6:0] opcode,
    output reg branch,
    output reg reg_write,
    output reg alu_src,
    output reg mem_read,
    output reg mem_write,
    output reg mem_to_reg,
    output reg [1:0] alu_op,
    output reg jump,
    output reg jalr, //target is rs1 + imm rather than pc + imm
    output reg [1:0] alu_a_src, //00=register, 01=PC (AUIPC), 10=zero (LUI)
    //Which source-register fields are real for this format. The rs1/rs2 bit
    //positions are fixed in every encoding, but in I/U/J formats they hold
    //immediate bits, so the hazard unit must not compare them.
    output reg uses_rs1, //R, I-ALU, load, store, branch, JALR
    output reg uses_rs2, //R, store, branch
    output reg halt,     //ECALL or EBREAK: stop the core once it commits
    output reg illegal   //opcode is not RV32I: stop the core and flag an error
);
always @(*) begin
    reg_write  = 0;
    alu_src    = 0;
    mem_read   = 0;
    mem_write  = 0;
    mem_to_reg = 0;
    branch=0;
    alu_op     = 2'b00;
    alu_a_src  = 2'b00;
    jump       = 0;
    jalr       = 0;
    uses_rs1   = 0;
    uses_rs2   = 0;
    halt       = 0;
    illegal    = 0;
    case(opcode)
        7'b0110011: begin //R-type ADD
            uses_rs1   = 1;
            uses_rs2   = 1;
            reg_write  = 1;
            alu_src    = 0;
            alu_op     = 2'b10;
        end
        7'b0010011: begin //I-type ALU: ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI
            uses_rs1   = 1;
            reg_write  = 1;
            alu_src    = 1;
            alu_op     = 2'b11; //decode funct3 (and funct7[5] for shifts)
        end
        7'b0000011: begin // Load (LW)
            uses_rs1   = 1;
            reg_write  = 1;
            mem_read   = 1;
            mem_to_reg = 1; 
            alu_src    = 1;
            mem_write = 0;
            alu_op     = 2'b00;
        end

        7'b0100011: begin // Store (SW)
            uses_rs1   = 1;
            uses_rs2   = 1;
            reg_write  = 0;
            mem_write   = 1;
            mem_read = 0;
            mem_to_reg = 0; 
            alu_src    = 1;
            alu_op     = 2'b00;
        end
        7'b1100011: begin // BEQ
            uses_rs1   = 1;
            uses_rs2   = 1;
            reg_write  = 0;
            alu_src    = 0;
            mem_read   = 0;
            mem_write  = 0;
            mem_to_reg = 0;
            branch     = 1;
            alu_op     = 2'b01; // subtract rs1 - rs2
        end

        
        7'b0110111: begin // LUI: rd = 0 + imm
            reg_write  = 1;
            alu_src    = 1;
            alu_a_src  = 2'b10;
            alu_op     = 2'b00;
        end
        7'b0010111: begin // AUIPC: rd = pc + imm
            reg_write  = 1;
            alu_src    = 1;
            alu_a_src  = 2'b01;
            alu_op     = 2'b00;
        end
        7'b1101111: begin // JAL: rd = pc+4, PC = pc + j_imm
            reg_write  = 1;
            jump       = 1;
            alu_a_src  = 2'b01; //link value is PC + 4
        end
        7'b1100111: begin // JALR: rd = pc+4, PC = (rs1 + imm) with LSB cleared
            uses_rs1   = 1;
            reg_write  = 1;
            jump       = 1;
            jalr       = 1;
            alu_a_src  = 2'b01; //link value is PC + 4
        end
        7'b0001111: begin // FENCE: legal, and a NOP on this in-order, cacheless core
        end
        7'b1110011: begin // SYSTEM: ECALL / EBREAK. No OS to trap to, so both halt.
            halt       = 1;
        end
        //Every opcode not listed above is illegal. Setting the flag in the
        //default arm means nothing needs to remember to clear it. This also
        //catches all-zero words (0x00000000 is defined illegal) and, in
        //simulation, X words fetched from past the end of the program.
        default: begin
            illegal    = 1;
        end
        endcase
    end

endmodule

`default_nettype wire
