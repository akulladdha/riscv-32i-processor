`timescale 1ns/1ps
module x0_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/x0.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #700;
        chk("x0 stayed zero", dut.my_regfile.registers[0], 32'd0);
        chk("read x0  x1=0",  dut.my_regfile.registers[1], 32'd0);
        chk("after LUI x2=0", dut.my_regfile.registers[2], 32'd0);
        chk("after ADD x4=0", dut.my_regfile.registers[4], 32'd0);
        finish_test("x0");
    end
endmodule
