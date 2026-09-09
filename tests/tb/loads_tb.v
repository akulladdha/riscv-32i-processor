`timescale 1ns/1ps
module loads_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/loads.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #500;
        chk("LW  x3", dut.my_regfile.registers[3], 32'h87654321);
        chk("LB  x4", dut.my_regfile.registers[4], 32'h00000021);
        chk("LB  x5 sign-ext", dut.my_regfile.registers[5], 32'hFFFFFF87);
        chk("LBU x6 zero-ext", dut.my_regfile.registers[6], 32'h00000087);
        chk("LH  x7", dut.my_regfile.registers[7], 32'h00004321);
        chk("LH  x8 sign-ext", dut.my_regfile.registers[8], 32'hFFFF8765);
        chk("LHU x9 zero-ext", dut.my_regfile.registers[9], 32'h00008765);
        finish_test("loads");
    end
endmodule
