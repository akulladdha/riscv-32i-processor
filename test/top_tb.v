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

        // pipeline with flush needs ~15 cycles; 200ns gives safe margin
        #200;

        if (dut.my_regfile.registers[1] !== 32'd5) begin
            $display("FAIL: x1 expected 5, got %0d", dut.my_regfile.registers[1]);
            $finish;
        end

        if (dut.my_regfile.registers[2] !== 32'd5) begin
            $display("FAIL: x2 expected 5, got %0d", dut.my_regfile.registers[2]);
            $finish;
        end

        if (dut.my_regfile.registers[3] !== 32'd0) begin
            $display("FAIL: x3 expected 0 because BEQ should skip ADDI, got %0d", dut.my_regfile.registers[3]);
            $finish;
        end

        if (dut.my_regfile.registers[4] !== 32'd42) begin
            $display("FAIL: x4 expected 42, got %0d", dut.my_regfile.registers[4]);
            $finish;
        end

        $display("PASS: BEQ skipped the ADDI to x3 and executed the ADDI to x4.");
        $finish;
    end
endmodule
