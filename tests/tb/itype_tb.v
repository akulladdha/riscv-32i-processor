`timescale 1ns/1ps
module itype_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/itype.hex")) dut (.clk(clk), .rst(rst), .ce(1'b1));
    always #5 clk = ~clk;
    `include "checker.vh"
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #500;
        chk("XORI  x3",  dut.my_regfile.registers[3],  32'd6);
        chk("ORI   x4",  dut.my_regfile.registers[4],  32'd15);
        chk("ANDI  x5",  dut.my_regfile.registers[5],  32'd8);
        chk("SLTI  x6",  dut.my_regfile.registers[6],  32'd1);
        chk("SLTI  x7",  dut.my_regfile.registers[7],  32'd0);
        chk("SLTIU x8",  dut.my_regfile.registers[8],  32'd1);
        chk("SLTIU x9",  dut.my_regfile.registers[9],  32'd0);
        chk("SLLI  x10", dut.my_regfile.registers[10], 32'd48);
        chk("SRLI  x11", dut.my_regfile.registers[11], 32'd3);
        chk("SRAI  x12", dut.my_regfile.registers[12], 32'hFFFFFFFC);
        chk("SRLI  x13", dut.my_regfile.registers[13], 32'h3FFFFFFC);
        finish_test("itype");
    end
endmodule
