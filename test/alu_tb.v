`timescale 1ns / 1ps

module alu_tb();
    reg  [31:0] a_top;
    reg  [31:0] b_top;
    reg  [3:0]  op_top;
    wire [31:0] res_top;
    wire        zero_top;

    alu uut (
        .a(a_top),
        .b(b_top),
        .opcode(op_top),
        .result(res_top),
        .zero(zero_top)
    );

    initial begin
        $dumpfile("alu_test.vcd"); 
        $dumpvars(0, alu_tb);
        a_top = 32'd5;  
        b_top = 32'd10; 
        op_top = 4'b0000;
        #10;
        
        a_top = 32'd20; 
        b_top = 32'd6;  
        op_top = 4'b0001;
        #10;

        a_top = 32'hAAAA_AAAA; 
        b_top = 32'h5555_5555; 
        op_top = 4'b0010;
        #10;

        $finish;
    end
endmodule