`timescale 1ns/1ps
module fence_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/fence.hex")) dut (.clk(clk), .rst(rst), .ce(1'b1));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #700;
        chk("before fence x1=5",  dut.my_regfile.registers[1], 32'd5);
        chk("after fence  x2=6",  dut.my_regfile.registers[2], 32'd6);
        chk("pipeline ok  x3=11", dut.my_regfile.registers[3], 32'd11);
        finish_test("fence");
    end
endmodule
