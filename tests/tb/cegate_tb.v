`timescale 1ns/1ps
//Clock-enable test by reference comparison. Two copies of the CPU run the same
//program: "ref" with ce held high, "gated" with ce from a pseudo-random LFSR.
//If every state element honours ce, pausing is invisible and both must end in
//the same architectural state. A flop that ignores ce would make them diverge.
module cegate_tb();
    reg clk, rst;
    reg [15:0] lfsr;
    wire ce_rand = lfsr[0];

    riscv_top #(.PROGRAM("tests/progs/cegate.hex")) ref_cpu   (.clk(clk), .rst(rst), .ce(1'b1));
    riscv_top #(.PROGRAM("tests/progs/cegate.hex")) gated_cpu (.clk(clk), .rst(rst), .ce(ce_rand));

    always #5 clk = ~clk;
    `include "checker.vh"

    //16-bit maximal-length LFSR (taps 16,14,13,11): a cheap, repeatable
    //pseudo-random bit stream - also a common hardware building block
    always @(posedge clk)
        if (rst) lfsr <= 16'hACE1;
        else     lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

    integer i, gated_cycles, paused;
    always @(posedge clk) if (!rst && !gated_cpu.halted) begin
        gated_cycles = gated_cycles + 1;
        if (!ce_rand) paused = paused + 1;
    end

    initial begin
        errors = 0; gated_cycles = 0; paused = 0;
        clk = 0; rst = 1; #15; rst = 0;
        wait (ref_cpu.halted === 1'b1 && gated_cpu.halted === 1'b1);
        #50;
        $display("  info: gated CPU paused on %0d of %0d cycles", paused, gated_cycles);
        chk("sanity: ref x10=89", ref_cpu.my_regfile.registers[10], 32'd89);
        chk("sanity: ref x14=7",  ref_cpu.my_regfile.registers[14], 32'd7);
        for (i = 1; i < 32; i = i + 1)
            if (gated_cpu.my_regfile.registers[i] !== ref_cpu.my_regfile.registers[i]) begin
                $display("  FAIL x%0d: gated %0d, ref %0d", i,
                         gated_cpu.my_regfile.registers[i], ref_cpu.my_regfile.registers[i]);
                errors = errors + 1;
            end
        chk("PC matches",    gated_cpu.pc_out, ref_cpu.pc_out);
        chk("error matches", gated_cpu.error,  ref_cpu.error);
        chk("ce really paused (>20 cycles)", paused > 20, 32'd1);
        finish_test("cegate");
    end

    initial begin #20000; $display("  FAIL timeout: a CPU never halted"); errors = errors + 1; finish_test("cegate"); end
endmodule
