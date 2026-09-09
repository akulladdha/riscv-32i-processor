module control_unit(
    input [6:0] opcode,
    output reg branch,
    output reg reg_write,
    output reg alu_src,
    output reg mem_read,
    output reg mem_write,
    output reg mem_to_reg,
    output reg [1:0] alu_op,
    output reg jump,
    output reg [1:0] alu_a_src //00=register, 01=PC (AUIPC), 10=zero (LUI)

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
    case(opcode)
        7'b0110011: begin //R-type ADD
            reg_write  = 1;
            alu_src    = 0;
            alu_op     = 2'b10;
        end
        7'b0010011: begin //I-type ALU: ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI
            reg_write  = 1;
            alu_src    = 1;
            alu_op     = 2'b11; //decode funct3 (and funct7[5] for shifts)
        end
        7'b0000011: begin // Load (LW)
            reg_write  = 1;
            mem_read   = 1;
            mem_to_reg = 1; 
            alu_src    = 1;
            mem_write = 0;
            alu_op     = 2'b00;
        end

        7'b0100011: begin // Store (SW)
            reg_write  = 0;
            mem_write   = 1;
            mem_read = 0;
            mem_to_reg = 0; 
            alu_src    = 1;
            alu_op     = 2'b00;
        end
        7'b1100011: begin // BEQ
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
        default: begin
            
        end
        endcase
    end

endmodule