// Shared self-checking helpers. `include this inside a testbench module.
// Usage:  errors = 0; ... chk("x1", dut.my_regfile.registers[1], 32'd5);
//         finish_test("my_test");

integer errors;

task chk;
    input [8*32:1] name;
    input [31:0]   got;
    input [31:0]   exp;
begin
    if (got !== exp) begin
        $display("  FAIL %0s: expected %0d (0x%08h), got %0d (0x%08h)", name, exp, exp, got, got);
        errors = errors + 1;
    end else begin
        $display("  ok   %0s = %0d (0x%08h)", name, got, got);
    end
end
endtask

task finish_test;
    input [8*32:1] tname;
begin
    if (errors == 0) $display("TEST %0s: PASS", tname);
    else             $display("TEST %0s: FAIL (%0d errors)", tname, errors);
    $finish;
end
endtask
