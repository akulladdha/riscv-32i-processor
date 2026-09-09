`timescale 1ns/1ps
module fwd_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/fwd.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #700;
        chk("EX/MEM fwd    x2=8",  dut.my_regfile.registers[2],  32'd8);
        chk("MEM/WB fwd    x5=25", dut.my_regfile.registers[5],  32'd25);
        chk("contention    x7=9",  dut.my_regfile.registers[7],  32'd9);
        chk("store-data fwd x10=42", dut.my_regfile.registers[10], 32'd42);
        finish_test("fwd");
    end
endmodule
