`timescale 1ns/1ps
module stores_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/stores.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #600;
        chk("SB  merged x6",  dut.my_regfile.registers[6],  32'h00550077);
        chk("SH  merged x12", dut.my_regfile.registers[12], 32'h04560123);
        finish_test("stores");
    end
endmodule
