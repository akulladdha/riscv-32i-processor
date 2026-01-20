module alu (
    input [31:0] a,
    input [31:0] b,
    input [3:0] opcode,
    output reg [31:0] result,
    output wire zero 

);
    always @(*) begin
        case (opcode)
            4'b0000: result = a + b; //add
            4'b0001: result = a - b; //sub
            4'b0010: result = a & b; //and
            4'b0011: result = a | b; //or
            
            //discarded for now
            /*4'b0100: result = a ^ b; //xor
            4'b0101: result = ~(a | b); //nor
            4'b0110: result = ~(a & b); //nand
            4'b0111: result = (a<b) ? 32'd1 : 32'd0; //set less than
            4'b1000: result = a << b[4:0]; //shift left logical
            4'b1001: result = a >> b[4:0]; //shift right logical*/
            default: result = 32'b0; 
        endcase
    end

    assign zero = (result == 32'b0);

endmodule