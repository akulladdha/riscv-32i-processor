`default_nettype none
module riscv_top #(
    parameter PROGRAM = "sample_program.hex"
)(
    input  wire clk,
    input  wire rst,
    input  wire ce,     //clock enable: the core advances only on cycles where ce=1
    //debug observation ports: read-only views of architectural state, so a
    //board wrapper can display the CPU (and so synthesis keeps it)
    input  wire [4:0]  dbg_reg_sel,
    output wire [31:0] dbg_reg_data,
    output wire [31:0] dbg_pc,
    output reg  halted, //sticky: an ECALL/EBREAK or illegal instruction committed
    output reg  error   //sticky: the halt was caused by an illegal instruction
);

    //Canonical NOP, ADDI x0, x0, 0. Bubbles inserted into IF/ID must be a real
    //instruction: the all-zero word is defined ILLEGAL by RISC-V, and would
    //now halt the core on every flush.
    localparam [31:0] NOP = 32'h00000013;

    //IF stage wires
    wire [31:0] if_instr;
    wire [31:0] pc_out;
    wire [31:0] if_pc_plus4;

    //IF/ID pipeline register
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;

    //ID stage wires decoded from if_id_instr
    wire [6:0]  id_opcode = if_id_instr[6:0];
    wire [4:0]  id_rd     = if_id_instr[11:7];
    wire [2:0]  id_funct3 = if_id_instr[14:12];
    wire [4:0]  id_rs1    = if_id_instr[19:15];
    wire [4:0]  id_rs2    = if_id_instr[24:20];
    wire [6:0]  id_funct7 = if_id_instr[31:25];

    wire [31:0] id_reg_data1, id_reg_data2;
    wire [31:0] id_imm_ext; //driven by imm_gen's output port
    wire        id_reg_write, id_alu_src, id_mem_read, id_mem_write, id_mem_to_reg, id_branch;
    wire [1:0]  id_alu_op;
    wire [3:0]  id_alu_control;
    wire [1:0]  id_alu_a_src;
    wire        id_jump;
    wire        id_jalr;
    wire        id_uses_rs1, id_uses_rs2;
    wire        id_halt, id_illegal;

    //ID/EX pipeline register
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_reg_data1;
    reg [31:0] id_ex_reg_data2;
    reg [31:0] id_ex_imm_ext;
    reg [4:0]  id_ex_rd;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [2:0]  id_ex_funct3;
    reg [3:0]  id_ex_alu_control; //decoded in ID; replaces alu_op + funct7
    reg        id_ex_reg_write;
    reg        id_ex_alu_src;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_mem_to_reg;
    reg        id_ex_branch;
    reg [1:0]  id_ex_alu_a_src;
    reg        id_ex_jump;
    reg        id_ex_jalr;
    reg        id_ex_halt;
    reg        id_ex_illegal;

    //EX stage wires
    wire [31:0] ex_alu_a;
    wire [31:0] ex_alu_b_reg;
    wire [31:0] ex_alu_src2;
    wire [31:0] ex_alu_result;
    wire [31:0] ex_branch_target;
    wire [31:0] ex_jump_target;

    //EX/MEM pipeline register
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_reg_data2;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_to_reg;
    reg [2:0]  ex_mem_funct3;

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
    //branch condition selected by funct3, evaluated on the forwarded operands
    //so a branch can compare values that are still in flight
    reg branch_cond;
    always @(*) begin
        case (id_ex_funct3)
            3'b000:  branch_cond = (ex_alu_a == ex_alu_b_reg);                   //BEQ
            3'b001:  branch_cond = (ex_alu_a != ex_alu_b_reg);                   //BNE
            3'b100:  branch_cond = ($signed(ex_alu_a) <  $signed(ex_alu_b_reg)); //BLT
            3'b101:  branch_cond = ($signed(ex_alu_a) >= $signed(ex_alu_b_reg)); //BGE
            3'b110:  branch_cond = (ex_alu_a <  ex_alu_b_reg);                   //BLTU
            3'b111:  branch_cond = (ex_alu_a >= ex_alu_b_reg);                   //BGEU
            default: branch_cond = 1'b0;
        endcase
    end
    wire branch_taken = id_ex_branch && branch_cond;
    //JAL is unconditional: it redirects as soon as it reaches EX
    wire jump_taken   = id_ex_jump;
    wire redirect     = branch_taken || jump_taken;
    wire flush        = redirect;

    //Halt. Requested from EX, not ID: EX is this pipeline's commit point, the
    //first stage where nothing older can still redirect away from the
    //instruction. Halting from ID would obey a wrong-path ECALL sitting in the
    //shadow of a taken branch (tests/progs/halt.s checks exactly that).
    wire halt_req = id_ex_halt || id_ex_illegal;
    //stop: freeze the front end (PC, IF/ID, ID/EX) from the moment the halting
    //instruction is in EX. MEM and WB are left alone, so older instructions
    //drain and commit normally.
    wire stop     = halt_req || halted;

    //sticky status: set once, held until reset
    always @(posedge clk) begin
        if (rst) begin
            halted <= 1'b0;
            error  <= 1'b0;
        end else if (ce && halt_req && !halted) begin
            halted <= 1'b1;
            error  <= id_ex_illegal;
        end
    end

    assign if_pc_plus4 = pc_out + 32'd4;
    //use ex_branch_target directly — it's valid while BEQ is in EX
    wire [31:0] pc_next = redirect ? ex_jump_target : if_pc_plus4;

    wire stall;
    hazard_unit my_hazard (
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_rd(id_ex_rd),
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .id_uses_rs1(id_uses_rs1),
        .id_uses_rs2(id_uses_rs2),
        .stall(stall)
    );

    //hold PC when stalling or stopped
    wire [31:0] pc_in_mux = (!ce || stall || stop) ? pc_out : pc_next;

    pc my_pc (
        .clk(clk),
        .reset(rst),
        .pc_in(pc_in_mux),
        .pc_out(pc_out)
    );

    instruction_mem #(.PROGRAM(PROGRAM)) my_imem (
        .addr(pc_out),
        .instruction(if_instr)
    );

    //IF/ID register: NOP on reset, taken branch, or halt; hold on stall
    always @(posedge clk) begin
        if (rst || (ce && (flush || stop))) begin
            if_id_pc       <= 32'b0;
            if_id_instr    <= NOP;
        end else if (ce && !stall) begin
            if_id_pc       <= pc_out;
            if_id_instr    <= if_instr;
        end
    end

    imm_gen my_imm_gen (
        .instr(if_id_instr),
        .imm(id_imm_ext)
    );

    control_unit my_cu (
        .opcode(id_opcode),
        .reg_write(id_reg_write),
        .alu_src(id_alu_src),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .mem_to_reg(id_mem_to_reg),
        .alu_op(id_alu_op),
        .branch(id_branch),
        .alu_a_src(id_alu_a_src),
        .jump(id_jump),
        .jalr(id_jalr),
        .uses_rs1(id_uses_rs1),
        .uses_rs2(id_uses_rs2),
        .halt(id_halt),
        .illegal(id_illegal)
    );

    //ALU decode happens in ID, in parallel with the register-file read, so
    //ID/EX carries the 4-bit answer instead of alu_op + funct7 and the
    //decoder's delay is off the EX critical path.
    alu_decoder my_alu_decoder (
        .alu_op(id_alu_op),
        .funct3(id_funct3),
        .funct7_5(id_funct7[5]),
        .alu_control(id_alu_control)
    );

    //register reads happen in ID, writeback comes from MEM/WB
    reg_file my_regfile (
        .clk(clk),
        .rst(rst),
        .rg_write_en(mem_wb_reg_write && ce), //a write is a state change: gate it
        .rg_des_addr(mem_wb_rd),
        .rg_sr1_addr(id_rs1),
        .rg_sr2_addr(id_rs2),
        .rg_des_data(wb_write_data),
        .rg_sr1_data(id_reg_data1),
        .rg_sr2_data(id_reg_data2),
        .dbg_addr(dbg_reg_sel),
        .dbg_data(dbg_reg_data)
    );

    //ID/EX register: inject NOP bubble on stall, flush, or halt
    always @(posedge clk) begin
        if (rst || (ce && (stall || flush || stop))) begin
            id_ex_pc         <= 32'b0;
            id_ex_reg_data1  <= 32'b0;
            id_ex_reg_data2  <= 32'b0;
            id_ex_imm_ext    <= 32'b0;
            id_ex_rd         <= 5'b0;
            id_ex_rs1        <= 5'b0;
            id_ex_rs2        <= 5'b0;
            id_ex_funct3     <= 3'b0;
            id_ex_alu_control <= 4'b0;
            id_ex_reg_write  <= 1'b0;
            id_ex_alu_src    <= 1'b0;
            id_ex_mem_read   <= 1'b0;
            id_ex_mem_write  <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch     <= 1'b0;
            id_ex_alu_a_src  <= 2'b0;
            id_ex_jump       <= 1'b0;
            id_ex_jalr       <= 1'b0;
            id_ex_halt       <= 1'b0;
            id_ex_illegal    <= 1'b0;
        end else if (ce) begin
            id_ex_pc         <= if_id_pc;
            id_ex_reg_data1  <= id_reg_data1;
            id_ex_reg_data2  <= id_reg_data2;
            id_ex_imm_ext    <= id_imm_ext;
            id_ex_rd         <= id_rd;
            id_ex_rs1        <= id_rs1;
            id_ex_rs2        <= id_rs2;
            id_ex_funct3     <= id_funct3;
            id_ex_alu_control <= id_alu_control;
            id_ex_reg_write  <= id_reg_write;
            id_ex_alu_src    <= id_alu_src;
            id_ex_mem_read   <= id_mem_read;
            id_ex_mem_write  <= id_mem_write;
            id_ex_mem_to_reg <= id_mem_to_reg;
            id_ex_branch     <= id_branch;
            id_ex_alu_a_src  <= id_alu_a_src;
            id_ex_jump       <= id_jump;
            id_ex_jalr       <= id_jalr;
            id_ex_halt       <= id_halt;
            id_ex_illegal    <= id_illegal;
        end
    end

    wire [1:0] forward_a, forward_b;
    forwarding_unit my_fwd (
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    //AUIPC takes PC as operand A, LUI takes zero; both bypass forwarding
    //because neither instruction's rs1 field is a register specifier.
    //forwarded rs1, kept as its own wire because JALR needs it for the target
    //while ex_alu_a is carrying the PC for the link value
    wire [31:0] ex_fwd_rs1 = (forward_a == 2'b10) ? ex_mem_alu_result :
                             (forward_a == 2'b01) ? wb_write_data :
                             id_ex_reg_data1;

    assign ex_alu_a     = (id_ex_alu_a_src == 2'b01) ? id_ex_pc :
                          (id_ex_alu_a_src == 2'b10) ? 32'b0 :
                          ex_fwd_rs1;

    assign ex_alu_b_reg = (forward_b == 2'b10) ? ex_mem_alu_result :
                          (forward_b == 2'b01) ? wb_write_data :
                          id_ex_reg_data2;

    //a jump computes its link value as PC + 4 through the normal ALU path,
    //so no extra writeback mux is needed
    assign ex_alu_src2     = id_ex_jump  ? 32'd4 :
                             id_ex_alu_src ? id_ex_imm_ext : ex_alu_b_reg;
    assign ex_branch_target = id_ex_pc + id_ex_imm_ext;
    //JALR targets rs1 + imm with bit 0 forced to zero, per the spec
    assign ex_jump_target   = id_ex_jalr ? ((ex_fwd_rs1 + id_ex_imm_ext) & ~32'd1)
                                         : ex_branch_target;

    alu my_alu (
        .opcode(id_ex_alu_control),
        .a(ex_alu_a),
        .b(ex_alu_src2),
        .result(ex_alu_result)
    );

    //EX/MEM register
    always @(posedge clk) begin
        if (rst) begin
            ex_mem_alu_result    <= 32'b0;
            ex_mem_reg_data2     <= 32'b0;
            ex_mem_rd            <= 5'b0;
            ex_mem_reg_write     <= 1'b0;
            ex_mem_mem_read      <= 1'b0;
            ex_mem_mem_write     <= 1'b0;
            ex_mem_mem_to_reg    <= 1'b0;
            ex_mem_funct3        <= 3'b0;
        end else if (ce) begin
            ex_mem_alu_result    <= ex_alu_result;
            ex_mem_reg_data2     <= ex_alu_b_reg; //forwarded rs2 for SW
            ex_mem_rd            <= id_ex_rd;
            ex_mem_reg_write     <= id_ex_reg_write;
            ex_mem_mem_read      <= id_ex_mem_read;
            ex_mem_mem_write     <= id_ex_mem_write;
            ex_mem_mem_to_reg    <= id_ex_mem_to_reg;
            ex_mem_funct3        <= id_ex_funct3;
        end
    end

    //store lane select. The data is replicated across all four lanes so the
    //byte enable alone decides which part of the word is written, which keeps
    //the memory free of any shift logic.
    reg [3:0]  mem_byte_en;
    reg [31:0] mem_store_data;
    always @(*) begin
        case (ex_mem_funct3)
            3'b000: begin //SB
                mem_byte_en    = 4'b0001 << ex_mem_alu_result[1:0];
                mem_store_data = {4{ex_mem_reg_data2[7:0]}};
            end
            3'b001: begin //SH
                mem_byte_en    = ex_mem_alu_result[1] ? 4'b1100 : 4'b0011;
                mem_store_data = {2{ex_mem_reg_data2[15:0]}};
            end
            default: begin //SW
                mem_byte_en    = 4'b1111;
                mem_store_data = ex_mem_reg_data2;
            end
        endcase
    end

    data_mem my_dmem (
        .clk(clk),
        .mem_read(ex_mem_mem_read),
        .mem_write(ex_mem_mem_write && ce),
        .byte_en(mem_byte_en),
        .addr(ex_mem_alu_result),
        .write_data(mem_store_data),
        .read_data(mem_read_data)
    );

    //sub-word load extraction and extension. The word comes back from data_mem
    //whole; funct3 picks the width and whether to sign- or zero-extend, and the
    //low address bits pick which byte/halfword within the word (little-endian).
    wire [7:0]  mem_byte = mem_read_data >> (8 * ex_mem_alu_result[1:0]);
    wire [15:0] mem_half = mem_read_data >> (16 * ex_mem_alu_result[1]);
    reg  [31:0] mem_load_data;
    always @(*) begin
        case (ex_mem_funct3)
            3'b000:  mem_load_data = {{24{mem_byte[7]}},  mem_byte}; //LB
            3'b001:  mem_load_data = {{16{mem_half[15]}}, mem_half}; //LH
            3'b100:  mem_load_data = {24'b0, mem_byte};              //LBU
            3'b101:  mem_load_data = {16'b0, mem_half};              //LHU
            default: mem_load_data = mem_read_data;                  //LW
        endcase
    end

    //MEM/WB register
    always @(posedge clk) begin
        if (rst) begin
            mem_wb_alu_result  <= 32'b0;
            mem_wb_read_data   <= 32'b0;
            mem_wb_rd          <= 5'b0;
            mem_wb_reg_write   <= 1'b0;
            mem_wb_mem_to_reg  <= 1'b0;
        end else if (ce) begin
            mem_wb_alu_result  <= ex_mem_alu_result;
            mem_wb_read_data   <= mem_load_data;
            mem_wb_rd          <= ex_mem_rd;
            mem_wb_reg_write   <= ex_mem_reg_write;
            mem_wb_mem_to_reg  <= ex_mem_mem_to_reg;
        end
    end

    assign dbg_pc = pc_out;

    assign wb_write_data = mem_wb_mem_to_reg ? mem_wb_read_data : mem_wb_alu_result;

endmodule

`default_nettype wire
