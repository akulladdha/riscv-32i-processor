module riscv_top(
    input clk,
    input rst
);

    //IF stage wires
    wire [31:0] if_instr;
    wire [31:0] pc_out;
    wire [31:0] if_pc_plus4;

    //IF/ID pipeline register
    reg [31:0] if_id_pc;
    reg [31:0] if_id_pc_plus4;
    reg [31:0] if_id_instr;

    //ID stage wires decoded from if_id_instr
    wire [6:0]  id_opcode = if_id_instr[6:0];
    wire [4:0]  id_rd     = if_id_instr[11:7];
    wire [2:0]  id_funct3 = if_id_instr[14:12];
    wire [4:0]  id_rs1    = if_id_instr[19:15];
    wire [4:0]  id_rs2    = if_id_instr[24:20];
    wire [6:0]  id_funct7 = if_id_instr[31:25];

    wire [31:0] id_reg_data1, id_reg_data2;
    wire [31:0] id_imm_ext;
    wire        id_reg_write, id_alu_src, id_mem_read, id_mem_write, id_mem_to_reg, id_branch;
    wire [1:0]  id_alu_op;

    //ID/EX pipeline register
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_pc_plus4;
    reg [31:0] id_ex_reg_data1;
    reg [31:0] id_ex_reg_data2;
    reg [31:0] id_ex_imm_ext;
    reg [4:0]  id_ex_rd;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [2:0]  id_ex_funct3;
    reg [6:0]  id_ex_funct7;
    reg        id_ex_reg_write;
    reg        id_ex_alu_src;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_mem_to_reg;
    reg        id_ex_branch;
    reg [1:0]  id_ex_alu_op;

    //EX stage wires
    reg  [3:0]  ex_alu_control;
    wire [31:0] ex_alu_a;
    wire [31:0] ex_alu_b_reg;
    wire [31:0] ex_alu_src2;
    wire [31:0] ex_alu_result;
    wire        ex_zero;
    wire [31:0] ex_branch_target;

    //EX/MEM pipeline register
    reg [31:0] ex_mem_pc_plus4;
    reg [31:0] ex_mem_branch_target;
    reg [31:0] ex_mem_alu_result;
    reg        ex_mem_zero;
    reg [31:0] ex_mem_reg_data2;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_to_reg;
    reg        ex_mem_branch;

    //MEM stage wires
    wire [31:0] mem_read_data;

    //MEM/WB pipeline register
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_read_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_to_reg;

    //WB stage wire
    wire [31:0] wb_write_data;

    //detect branch taken while BEQ is still in EX (early detection)
    //using ex_mem signals would be 1 cycle too late — the wrong instruction
    //would already be latched into ID/EX and propagate one more stage
    wire branch_taken = id_ex_branch && ex_zero;
    wire flush        = branch_taken;

    assign if_pc_plus4 = pc_out + 32'd4;
    //use ex_branch_target directly — it's valid while BEQ is in EX
    wire [31:0] pc_next = branch_taken ? ex_branch_target : if_pc_plus4;

    //load-use hazard: stall if LW in EX and dependent instruction in ID
    wire stall = id_ex_mem_read &&
                 (id_ex_rd != 5'b0) &&
                 ((id_ex_rd == id_rs1) || (id_ex_rd == id_rs2));

    //hold PC when stalling
    wire [31:0] pc_in_mux = stall ? pc_out : pc_next;

    pc my_pc (
        .clk(clk),
        .reset(rst),
        .pc_in(pc_in_mux),
        .pc_out(pc_out)
    );

    instruction_mem my_imem (
        .addr(pc_out),
        .instruction(if_instr)
    );

    //IF/ID register: flush on taken branch, hold on stall
    always @(posedge clk) begin
        if (rst || flush) begin
            if_id_pc       <= 32'b0;
            if_id_pc_plus4 <= 32'b0;
            if_id_instr    <= 32'b0;
        end else if (!stall) begin
            if_id_pc       <= pc_out;
            if_id_pc_plus4 <= if_pc_plus4;
            if_id_instr    <= if_instr;
        end
    end

    //immediate generation
    wire [31:0] i_ext = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
    wire [31:0] s_ext = {{20{if_id_instr[31]}}, if_id_instr[31:25], if_id_instr[11:7]};
    wire [31:0] b_ext = {{19{if_id_instr[31]}}, if_id_instr[31], if_id_instr[7],
                          if_id_instr[30:25], if_id_instr[11:8], 1'b0};
    assign id_imm_ext = (id_opcode == 7'b0000011 || id_opcode == 7'b0010011) ? i_ext :
                        (id_opcode == 7'b0100011) ? s_ext :
                        (id_opcode == 7'b1100011) ? b_ext :
                        32'b0;

    control_unit my_cu (
        .opcode(id_opcode),
        .reg_write(id_reg_write),
        .alu_src(id_alu_src),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .mem_to_reg(id_mem_to_reg),
        .alu_op(id_alu_op),
        .branch(id_branch)
    );

    //register reads happen in ID, writeback comes from MEM/WB
    reg_file my_regfile (
        .clk(clk),
        .rst(rst),
        .rg_write_en(mem_wb_reg_write),
        .rg_des_addr(mem_wb_rd),
        .rg_sr1_addr(id_rs1),
        .rg_sr2_addr(id_rs2),
        .rg_des_data(wb_write_data),
        .rg_sr1_data(id_reg_data1),
        .rg_sr2_data(id_reg_data2)
    );

    //ID/EX register: inject NOP bubble on stall or flush
    always @(posedge clk) begin
        if (rst || stall || flush) begin
            id_ex_pc         <= 32'b0;
            id_ex_pc_plus4   <= 32'b0;
            id_ex_reg_data1  <= 32'b0;
            id_ex_reg_data2  <= 32'b0;
            id_ex_imm_ext    <= 32'b0;
            id_ex_rd         <= 5'b0;
            id_ex_rs1        <= 5'b0;
            id_ex_rs2        <= 5'b0;
            id_ex_funct3     <= 3'b0;
            id_ex_funct7     <= 7'b0;
            id_ex_reg_write  <= 1'b0;
            id_ex_alu_src    <= 1'b0;
            id_ex_mem_read   <= 1'b0;
            id_ex_mem_write  <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch     <= 1'b0;
            id_ex_alu_op     <= 2'b0;
        end else begin
            id_ex_pc         <= if_id_pc;
            id_ex_pc_plus4   <= if_id_pc_plus4;
            id_ex_reg_data1  <= id_reg_data1;
            id_ex_reg_data2  <= id_reg_data2;
            id_ex_imm_ext    <= id_imm_ext;
            id_ex_rd         <= id_rd;
            id_ex_rs1        <= id_rs1;
            id_ex_rs2        <= id_rs2;
            id_ex_funct3     <= id_funct3;
            id_ex_funct7     <= id_funct7;
            id_ex_reg_write  <= id_reg_write;
            id_ex_alu_src    <= id_alu_src;
            id_ex_mem_read   <= id_mem_read;
            id_ex_mem_write  <= id_mem_write;
            id_ex_mem_to_reg <= id_mem_to_reg;
            id_ex_branch     <= id_branch;
            id_ex_alu_op     <= id_alu_op;
        end
    end

    //ALU control derived from alu_op + funct3/funct7
    always @(*) begin
        case (id_ex_alu_op)
            2'b00: ex_alu_control = 4'b0000; //ADD for load/store/ADDI
            2'b01: ex_alu_control = 4'b0001; //SUB for branch comparison
            2'b10: begin
                case (id_ex_funct3)
                    3'b000:  ex_alu_control = id_ex_funct7[5] ? 4'b0001 : 4'b0000; //SUB or ADD
                    3'b111:  ex_alu_control = 4'b0010; //AND
                    3'b110:  ex_alu_control = 4'b0011; //OR
                    default: ex_alu_control = 4'b0000;
                endcase
            end
            default: ex_alu_control = 4'b0000;
        endcase
    end

    //forwarding unit: select correct ALU source to resolve RAW hazards
    reg [1:0] forward_a, forward_b;
    always @(*) begin
        //EX/MEM forwarding (higher priority)
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;
        //MEM/WB forwarding
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

    assign ex_alu_a     = (forward_a == 2'b10) ? ex_mem_alu_result :
                          (forward_a == 2'b01) ? wb_write_data :
                          id_ex_reg_data1;

    assign ex_alu_b_reg = (forward_b == 2'b10) ? ex_mem_alu_result :
                          (forward_b == 2'b01) ? wb_write_data :
                          id_ex_reg_data2;

    assign ex_alu_src2     = id_ex_alu_src ? id_ex_imm_ext : ex_alu_b_reg;
    assign ex_branch_target = id_ex_pc + id_ex_imm_ext;

    alu my_alu (
        .opcode(ex_alu_control),
        .a(ex_alu_a),
        .b(ex_alu_src2),
        .result(ex_alu_result),
        .zero(ex_zero)
    );

    //EX/MEM register
    always @(posedge clk) begin
        if (rst) begin
            ex_mem_pc_plus4      <= 32'b0;
            ex_mem_branch_target <= 32'b0;
            ex_mem_alu_result    <= 32'b0;
            ex_mem_zero          <= 1'b0;
            ex_mem_reg_data2     <= 32'b0;
            ex_mem_rd            <= 5'b0;
            ex_mem_reg_write     <= 1'b0;
            ex_mem_mem_read      <= 1'b0;
            ex_mem_mem_write     <= 1'b0;
            ex_mem_mem_to_reg    <= 1'b0;
            ex_mem_branch        <= 1'b0;
        end else begin
            ex_mem_pc_plus4      <= id_ex_pc_plus4;
            ex_mem_branch_target <= ex_branch_target;
            ex_mem_alu_result    <= ex_alu_result;
            ex_mem_zero          <= ex_zero;
            ex_mem_reg_data2     <= ex_alu_b_reg; //forwarded rs2 for SW
            ex_mem_rd            <= id_ex_rd;
            ex_mem_reg_write     <= id_ex_reg_write;
            ex_mem_mem_read      <= id_ex_mem_read;
            ex_mem_mem_write     <= id_ex_mem_write;
            ex_mem_mem_to_reg    <= id_ex_mem_to_reg;
            ex_mem_branch        <= id_ex_branch;
        end
    end

    data_mem my_dmem (
        .clk(clk),
        .mem_read(ex_mem_mem_read),
        .mem_write(ex_mem_mem_write),
        .addr(ex_mem_alu_result),
        .write_data(ex_mem_reg_data2),
        .read_data(mem_read_data)
    );

    //MEM/WB register
    always @(posedge clk) begin
        if (rst) begin
            mem_wb_alu_result  <= 32'b0;
            mem_wb_read_data   <= 32'b0;
            mem_wb_rd          <= 5'b0;
            mem_wb_reg_write   <= 1'b0;
            mem_wb_mem_to_reg  <= 1'b0;
        end else begin
            mem_wb_alu_result  <= ex_mem_alu_result;
            mem_wb_read_data   <= mem_read_data;
            mem_wb_rd          <= ex_mem_rd;
            mem_wb_reg_write   <= ex_mem_reg_write;
            mem_wb_mem_to_reg  <= ex_mem_mem_to_reg;
        end
    end

    assign wb_write_data = mem_wb_mem_to_reg ? mem_wb_read_data : mem_wb_alu_result;

endmodule
