`timescale 1ns/1ps
module flush_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/flush.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #700;
        chk("flushed ID  x2=0",  dut.my_regfile.registers[2],  32'd0);
        chk("flushed IF  x3=0",  dut.my_regfile.registers[3],  32'd0);
        chk("target ran  x4=7",  dut.my_regfile.registers[4],  32'd7);
        chk("b2b flush   x13=0", dut.my_regfile.registers[13], 32'd0);
        chk("b2b flush   x14=0", dut.my_regfile.registers[14], 32'd0);
        chk("b2b target  x15=1", dut.my_regfile.registers[15], 32'd1);
        finish_test("flush");
    end
endmodule
