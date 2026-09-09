`timescale 1ns/1ps
module rtype_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/rtype.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #500;
        chk("XOR  x3",  dut.my_regfile.registers[3],  32'd6);
        chk("SLL  x4",  dut.my_regfile.registers[4],  32'd48);
        chk("SRL  x5",  dut.my_regfile.registers[5],  32'd3);
        chk("SRA  x10", dut.my_regfile.registers[10], 32'hFFFFFFFC);
        chk("SRL  x11", dut.my_regfile.registers[11], 32'h3FFFFFFC);
        chk("SLT  x12", dut.my_regfile.registers[12], 32'd1);
        chk("SLTU x13", dut.my_regfile.registers[13], 32'd0);
        chk("SLT  x14", dut.my_regfile.registers[14], 32'd0);
        chk("SLTU x15", dut.my_regfile.registers[15], 32'd1);
        chk("SLL  x17 shamt-mask", dut.my_regfile.registers[17], 32'd24);
        finish_test("rtype");
    end
endmodule
