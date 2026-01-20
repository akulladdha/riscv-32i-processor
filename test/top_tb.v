`timescale 1ns/1ps

module riscv_top_tb();
    reg clk;
    reg rst;

    riscv_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("riscv_processor.vcd");
        $dumpvars(0, riscv_top_tb);

        clk = 0;
        rst = 1;
        #15;
        rst = 0;
        #1000;

        $display("Simulation finished. Open riscv_processor.vcd in GTKWave.");
        $finish;
    end
endmodule