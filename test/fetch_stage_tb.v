`timescale 1ns/1ps

module fetch_stage_tb();
    reg clk;
    reg rst;
    wire [31:0] current_pc;
    wire [31:0] current_instruction;

    pc my_pc (
        .clk(clk),
        .reset(rst),
        .pc_out(current_pc)
    );

    instruction_mem my_imem (
        .addr(current_pc),
        .instruction(current_instruction)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("fetch_test.vcd");
        $dumpvars(0, fetch_stage_tb);

        rst = 1; #10;
        rst = 0;

        #40; 

        $finish;
    end
endmodule