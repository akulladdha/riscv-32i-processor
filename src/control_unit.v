module control_unit(
    input [6:0] opcode,
    output reg reg_write,
    output reg alu_src,
    output reg mem_read,
    output reg mem_write,
    output reg mem_to_reg,
    output reg [1:0] alu_op

);
always @(*) begin
    reg_write  = 0;
    alu_src    = 0;
    mem_read   = 0;
    mem_write  = 0;
    mem_to_reg = 0;
    alu_op     = 2'b00;
    case(opcode)
        7'b0110011: begin //R-type ADD
            reg_write  = 1;
            alu_src    = 0;
            alu_op     = 2'b10;
        end
        7'b0010011: begin //I-type ADDI
            reg_write  = 1;
            alu_src    = 1;
            alu_op     = 2'b00; //force add
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
        
        default: begin
            
        end
        endcase
    end

endmodule