`timescale 1ns/1ps
module utype_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/utype.hex")) dut (.clk(clk), .rst(rst), .ce(1'b1));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #400;
        chk("LUI   x1", dut.my_regfile.registers[1], 32'h12345000);
        chk("LUI   x2", dut.my_regfile.registers[2], 32'hFFFFF000);
        chk("AUIPC x3", dut.my_regfile.registers[3], 32'h00000008);
        chk("AUIPC x4", dut.my_regfile.registers[4], 32'h0000100C);
        chk("LUI+ADDI x5", dut.my_regfile.registers[5], 32'h12345111);
        finish_test("utype");
    end
endmodule
