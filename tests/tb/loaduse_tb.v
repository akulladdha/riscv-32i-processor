`timescale 1ns/1ps
module loaduse_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/loaduse.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #700;
        chk("load-use ALU    x4=8",  dut.my_regfile.registers[4], 32'd8);
        chk("load-use branch x5=0",  dut.my_regfile.registers[5], 32'd0);
        chk("branch target   x6=1",  dut.my_regfile.registers[6], 32'd1);
        finish_test("loaduse");
    end
endmodule
