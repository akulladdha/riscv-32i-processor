`timescale 1ns/1ps
module raw3_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/raw3.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #300;
        chk("x1 producer",  dut.my_regfile.registers[1], 32'd5);
        chk("x5 distance-3", dut.my_regfile.registers[5], 32'd5);
        chk("x6 distance-4", dut.my_regfile.registers[6], 32'd5);
        finish_test("raw3");
    end
endmodule
