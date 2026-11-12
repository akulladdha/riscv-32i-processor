`timescale 1ns/1ps
module jalr_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/jalr.hex")) dut (.clk(clk), .rst(rst), .ce(1'b1));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #600;
        chk("JALR link x5=12",      dut.my_regfile.registers[5],  32'd12);
        chk("JALR link x8=28",      dut.my_regfile.registers[8],  32'd28);
        chk("LSB cleared: x10=32",  dut.my_regfile.registers[10], 32'd32);
        chk("flushed x2=0",         dut.my_regfile.registers[2],  32'd0);
        chk("flushed x3=0",         dut.my_regfile.registers[3],  32'd0);
        chk("skipped x6=0",         dut.my_regfile.registers[6],  32'd0);
        chk("target ran x4=7",      dut.my_regfile.registers[4],  32'd7);
        finish_test("jalr");
    end
endmodule
