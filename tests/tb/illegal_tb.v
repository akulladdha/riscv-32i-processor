`timescale 1ns/1ps
module illegal_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/illegal.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #300;
        chk("older instr ran      x1=1", dut.my_regfile.registers[1], 32'd1);
        chk("younger instr killed x2=0", dut.my_regfile.registers[2], 32'd0);
        chk("halted=1",                  dut.halted, 32'd1);
        chk("error=1",                   dut.error,  32'd1);
        finish_test("illegal");
    end
endmodule
