`timescale 1ns / 1ps

module pc_tb();
    reg clk;
    reg reset;
    reg [31:0] pc_in;
    wire [31:0] pc_out;

    pc uut (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    initial begin
        $dumpfile("pc_test.vcd");
        $dumpvars(0, pc_tb);
        clk = 0;
    end
    always #5 clk = ~clk;

    initial begin //stimulus
        reset = 1;
        pc_in = 32'hA;
        #10;

        reset = 0;
        pc_in = 32'h0000_0004;
        #10;
        
        pc_in = 32'h0000_0008; 
        #10;

        $display("Final PC Value: %h", pc_out);
        $finish;
    end

endmodule