`timescale 1ns/1ps
module jal_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/jal.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #400;
        chk("JAL link x5=8",   dut.my_regfile.registers[5], 32'd8);
        chk("flushed x2=0",    dut.my_regfile.registers[2], 32'd0);
        chk("flushed x3=0",    dut.my_regfile.registers[3], 32'd0);
        chk("target ran x4=7", dut.my_regfile.registers[4], 32'd7);
        finish_test("jal");
    end
endmodule
