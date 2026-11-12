//ALU decoder: turns the coarse alu_op from control_unit plus the instruction's
//funct3 / funct7[5] into the 4-bit operation code the ALU executes.
//Purely combinational.
module alu_decoder (
    input      [1:0] alu_op,   //00 add, 01 sub, 10 R-type, 11 I-type ALU
    input      [2:0] funct3,
    input            funct7_5, //instr[30]: selects SUB vs ADD, SRA vs SRL
    output reg [3:0] alu_control
);

    //Must match the case labels in alu.v
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    always @(*) begin
        alu_control = ALU_ADD; //default first: no path can leave it unassigned
        case (alu_op)
            2'b00: alu_control = ALU_ADD; //loads, stores, LUI, AUIPC, link
            2'b01: alu_control = ALU_SUB;
            2'b10: case (funct3) //R-type
                3'b000: alu_control = funct7_5 ? ALU_SUB : ALU_ADD;
                3'b001: alu_control = ALU_SLL;
                3'b010: alu_control = ALU_SLT;
                3'b011: alu_control = ALU_SLTU;
                3'b100: alu_control = ALU_XOR;
                3'b101: alu_control = funct7_5 ? ALU_SRA : ALU_SRL;
                3'b110: alu_control = ALU_OR;
                3'b111: alu_control = ALU_AND;
            endcase
            //I-type: same funct3 map, but funct7_5 matters only for shifts.
            //funct3 000 is always ADDI - there is no SUBI, and bit 30 of an
            //ADDI is an immediate bit, so it must NOT select SUB here.
            2'b11: case (funct3)
                3'b000: alu_control = ALU_ADD;
                3'b001: alu_control = ALU_SLL;
                3'b010: alu_control = ALU_SLT;
                3'b011: alu_control = ALU_SLTU;
                3'b100: alu_control = ALU_XOR;
                3'b101: alu_control = funct7_5 ? ALU_SRA : ALU_SRL;
                3'b110: alu_control = ALU_OR;
                3'b111: alu_control = ALU_AND;
            endcase
        endcase
    end

endmodule
