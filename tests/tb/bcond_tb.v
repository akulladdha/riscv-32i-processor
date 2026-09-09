`timescale 1ns/1ps
module bcond_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/bcond.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #600;
        chk("BNE  taken     x10=0", dut.my_regfile.registers[10], 32'd0);
        chk("BEQ  not taken x11=1", dut.my_regfile.registers[11], 32'd1);
        chk("BLT  taken     x12=0", dut.my_regfile.registers[12], 32'd0);
        chk("BLTU not taken x13=1", dut.my_regfile.registers[13], 32'd1);
        chk("BGE  taken     x14=0", dut.my_regfile.registers[14], 32'd0);
        chk("BGEU taken     x15=0", dut.my_regfile.registers[15], 32'd0);
        chk("sentinel       x20=99", dut.my_regfile.registers[20], 32'd99);
        finish_test("bcond");
    end
endmodule
