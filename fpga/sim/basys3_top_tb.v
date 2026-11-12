`timescale 1ns/1ps
//Board-level test of basys3_top: exercises the wrapper the way a person at the
//board would. Counts are shrunk via parameters so it runs in microseconds of
//simulated time instead of seconds - the standard trick for simulating
//anything with human-scale timing.
module basys3_top_tb();
    reg         clk = 0, btnC = 0, btnU = 0;
    reg  [15:0] sw = 16'b0;
    wire [15:0] led;
    wire [6:0]  seg;
    wire [3:0]  an;
    wire        dp;

    basys3_top #(
        .PROGRAM("fpga/demo.hex"),
        .DEBOUNCE_CYCLES(8),
        .RUN_DIV_BITS(3),
        .REFRESH_BITS(4)
    ) dut (.clk(clk), .btnC(btnC), .btnU(btnU), .sw(sw),
           .led(led), .seg(seg), .dp(dp), .an(an));

    always #5 clk = ~clk;
    `include "checker.vh"

    //Count CPU clock enables directly. Checking only the PC is ambiguous: a
    //looping program revisits PCs, so extra steps can land on the expected PC
    //by coincidence (a no-debounce mutant did exactly that).
    integer ce_count = 0;
    always @(posedge clk) if (dut.cpu_ce) ce_count = ce_count + 1;

    //A realistic button press: contact bounce on the way down and on release.
    //The debouncer must turn this into exactly ONE step.
    task press_step;
        integer b;
        begin
            for (b = 0; b < 4; b = b + 1) begin btnU = 1; #20; btnU = 0; #20; end
            btnU = 1; #300;                       //held down, stable
            for (b = 0; b < 3; b = b + 1) begin btnU = 0; #20; btnU = 1; #20; end
            btnU = 0; #300;                       //released, stable
        end
    endtask

    //Wait until the display multiplexer is showing digit d, then sample it.
    task wait_digit;
        input [1:0] d;
        begin
            @(posedge clk);
            while (an !== ~(4'b0001 << d)) @(posedge clk);
        end
    endtask

    initial begin
        errors = 0;
        //1. power-on reset alone must bring the CPU up cleanly at PC 0
        #500;
        chk("after power-on reset PC=0", dut.dbg_pc, 32'd0);

        //2. single-step with a bouncing button: 3 presses = exactly 3 steps
        ce_count = 0;
        press_step; press_step; press_step;
        chk("3 presses = exactly 3 steps", ce_count, 32'd3);
        chk("3 bouncy presses = PC 12", dut.dbg_pc, 32'd12);
        chk("led[7:0] shows PC word 3", led[7:0], 32'd3);

        //3. reset button returns to PC 0
        btnC = 1; #100; btnC = 0; #100;
        chk("reset button -> PC 0", dut.dbg_pc, 32'd0);

        //4. run mode: the program completes and halts cleanly
        sw[15] = 1;
        wait (led[15] === 1'b1);
        #200;
        chk("halted LED", led[15], 32'd1);
        chk("error LED off", led[14], 32'd0);
        chk("run-mode LED", led[13], 32'd1);

        //5. display x10 = 0x0059 on the seven-segment display
        sw[4:0] = 5'd10; #100;
        chk("display value = 0x0059", dut.display_value, 32'h0059);
        wait_digit(0); @(posedge clk);
        chk("digit 0 segments = '9'", seg, {~7'h6F}); //braces: invert at 7 bits, THEN widen
        wait_digit(1); @(posedge clk);
        chk("digit 1 segments = '5'", seg, {~7'h6D});
        chk("decimal point off", dp, 32'd1);

        //6. sw[5] shows the PC; it must be frozen past the ECALL
        sw[5] = 1; #100;
        chk("PC display frozen at halt", dut.display_value, dut.dbg_pc[15:0]);

        finish_test("basys3_top");
    end

    initial begin #200000; $display("  FAIL timeout"); errors = errors + 1; finish_test("basys3_top"); end
endmodule
