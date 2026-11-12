`timescale 1ns/1ps
module stallprec_tb();
    reg clk, rst;
    riscv_top #(.PROGRAM("tests/progs/stallprec.hex")) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    `include "checker.vh"

    //Performance counter: cycles in which the hazard unit stalled the pipe.
    //This observes an internal signal by hierarchical reference, which is
    //fine in a testbench and impossible in synthesizable RTL.
    integer stalls = 0;
    always @(posedge clk) if (!rst && dut.stall === 1'b1) stalls = stalls + 1;

    initial begin
        errors = 0; clk = 0; rst = 1; #15; rst = 0; #500;
        chk("ADDI ran        x5=1",       dut.my_regfile.registers[5],  32'd1);
        chk("LUI ran         x6=0x10000", dut.my_regfile.registers[6],  32'h10000);
        chk("real dep        x8=7",       dut.my_regfile.registers[8],  32'd7);
        chk("finished        x10=99",     dut.my_regfile.registers[10], 32'd99);
        chk("stall cycles    =1",         stalls,                       32'd1);
        finish_test("stallprec");
    end
endmodule
