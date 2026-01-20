module riscv_top(
    input clk,
    input rst
);

    //Internal Wires
    wire [31:0] pc_out, instr;
    wire [31:0] reg_data1, reg_data2, write_data;
    wire [31:0] alu_result, read_data;
    wire [31:0] imm_ext;
    wire [31:0] alu_src2_mux;
    
    //Control Signals
    wire reg_write, alu_src, mem_read, mem_write, mem_to_reg;
    wire [1:0] alu_op;

    //Instruction Slicing
    wire [6:0]  opcode   = instr[6:0];
    wire [4:0]  rd       = instr[11:7];
    wire [2:0]  funct3   = instr[14:12];
    wire [4:0]  sr1      = instr[19:15];
    wire [4:0]  sr2      = instr[24:20];
    wire [6:0]  funct7   = instr[31:25];

    //Sign extension for I type
    wire [31:0] i_ext = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] s_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_ext = (opcode == 7'b0000011 || opcode == 7'b0010011) ? i_ext : // LW or ADDI
                     (opcode == 7'b0100011) ? s_ext : 32'b0; // SW

    pc my_pc (
        .clk(clk),
        .reset(rst),
        .pc_out(pc_out)
    );

    instruction_mem my_imem (
        .addr(pc_out),
        .instruction(instr)
    );

    control_unit my_cu (
        .opcode(opcode),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_op(alu_op)
    );

    reg_file my_regfile (
        .clk(clk),
        .rst(rst),
        .rg_write_en(reg_write),
        .rg_des_addr(rd),
        .rg_sr1_addr(sr1),
        .rg_sr2_addr(sr2),
        .rg_des_data(write_data),
        .rg_sr1_data(reg_data1),
        .rg_sr2_data(reg_data2)
    );

    reg [3:0] alu_control_signal;
    always @(*)begin
        case(alu_op)
            2'b00: alu_control_signal = 4'b0000; // ADD for Load/Store
            2'b01: alu_control_signal = 4'b0001; // SUB for Branch
            2'b10: begin
                case(funct3)
                    3'b000: alu_control_signal = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB or ADD
                    3'b111: alu_control_signal = 4'b0010; // AND
                    3'b110: alu_control_signal = 4'b0011; // OR
                endcase
            end
            default: alu_control_signal = 4'b0000;
        endcase
    end


    alu my_alu(
        .opcode(alu_control_signal),
        .a(reg_data1),
        .b(alu_src2_mux),
        .result(alu_result)
    );

    data_mem my_dmem(
    .clk(clk),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .addr(alu_result),
    .write_data(reg_data2),
    .read_data(read_data)
);
    
    assign alu_src2_mux = (alu_src) ? imm_ext : reg_data2;

    assign write_data = (mem_to_reg) ? read_data : alu_result;

endmodule