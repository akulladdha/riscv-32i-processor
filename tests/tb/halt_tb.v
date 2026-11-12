`timescale 1ns/1ps
module halt_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/halt.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"

    reg [31:0] pc_at_check;
    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #400;
        chk("wrong-path ECALL flushed x3=0", dut.my_regfile.registers[3], 32'd0);
        chk("ran past it          x4=1",     dut.my_regfile.registers[4], 32'd1);
        chk("older instr drained  x5=2",     dut.my_regfile.registers[5], 32'd2);
        chk("younger instr killed x6=0",     dut.my_regfile.registers[6], 32'd0);
        chk("younger instr killed x7=0",     dut.my_regfile.registers[7], 32'd0);
        chk("halted=1",                      dut.halted, 32'd1);
        chk("error=0 (clean halt)",          dut.error,  32'd0);
        //halt must be sticky and the PC frozen
        pc_at_check = dut.pc_out; #100;
        chk("PC frozen",                     dut.pc_out, pc_at_check);
        chk("still halted",                  dut.halted, 32'd1);
        finish_test("halt");
    end
endmodule
