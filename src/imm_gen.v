`default_nettype none
//Immediate generator: extracts and sign-extends the immediate for every
//RV32I format. Purely combinational - no clock, no state.
module imm_gen (
    input  wire [31:0] instr,
    output reg [31:0] imm
);

    //RV32I base opcodes (instr[6:0])
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_JAL    = 7'b1101111;

    //All five formats are computed in parallel; the case only selects one.
    //This is just wiring plus replication - sign extension costs no gates,
    //it is instr[31] fanned out to the upper bits.
    wire [31:0] i_ext = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] s_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] b_ext = {{19{instr[31]}}, instr[31], instr[7],
                         instr[30:25], instr[11:8], 1'b0};
    wire [31:0] u_ext = {instr[31:12], 12'b0};
    wire [31:0] j_ext = {{11{instr[31]}}, instr[31], instr[19:12],
                         instr[20], instr[30:21], 1'b0};

    //opcodes are mutually exclusive, so a case (parallel select) states the
    //intent; a ?: chain would describe a priority cascade that never matters
    always @(*) begin
        case (instr[6:0])
            OP_LOAD, OP_IMM, OP_JALR: imm = i_ext;
            OP_STORE:                 imm = s_ext;
            OP_BRANCH:                imm = b_ext;
            OP_LUI, OP_AUIPC:         imm = u_ext;
            OP_JAL:                   imm = j_ext;
            default:                  imm = 32'b0; //R-type has no immediate
        endcase
    end

endmodule

`default_nettype wire
