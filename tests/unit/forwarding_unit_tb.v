`timescale 1ns/1ps
//Unit test for forwarding_unit. The DUT is combinational, so there is no
//clock: drive the inputs, wait a moment for them to settle, check outputs.
module forwarding_unit_tb();
    reg  [4:0] rs1, rs2, em_rd, mw_rd;
    reg        em_we, mw_we;
    wire [1:0] fa, fb;
    integer errors = 0;

    forwarding_unit dut (
        .id_ex_rs1(rs1), .id_ex_rs2(rs2),
        .ex_mem_rd(em_rd), .ex_mem_reg_write(em_we),
        .mem_wb_rd(mw_rd), .mem_wb_reg_write(mw_we),
        .forward_a(fa), .forward_b(fb)
    );

    //A task bundles "apply stimulus, then check" so each case is one line.
    //Unlike a function, a task may consume time (#1 here).
    task check;
        input [8*24-1:0] name;
        input [4:0] t_rs1, t_rs2, t_em_rd; input t_em_we;
        input [4:0] t_mw_rd; input t_mw_we;
        input [1:0] exp_a, exp_b;
        begin
            rs1 = t_rs1; rs2 = t_rs2; em_rd = t_em_rd; em_we = t_em_we;
            mw_rd = t_mw_rd; mw_we = t_mw_we;
            #1;
            if (fa !== exp_a || fb !== exp_b) begin
                $display("FAIL %0s: fa=%b fb=%b, expected %b %b", name, fa, fb, exp_a, exp_b);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        //           name                   rs1 rs2 emrd emwe mwrd mwwe  a      b
        check("no hazard",                 1,  2,  3,   1,   4,   1,   2'b00, 2'b00);
        check("EX/MEM -> A",               1,  2,  1,   1,   4,   1,   2'b10, 2'b00);
        check("EX/MEM -> B",               1,  2,  2,   1,   4,   1,   2'b00, 2'b10);
        check("MEM/WB -> A",               1,  2,  3,   1,   1,   1,   2'b01, 2'b00);
        check("MEM/WB -> B",               1,  2,  3,   1,   2,   1,   2'b00, 2'b01);
        check("both stages: EX/MEM wins",  1,  2,  1,   1,   1,   1,   2'b10, 2'b00);
        check("same reg both operands",    5,  5,  5,   1,   9,   0,   2'b10, 2'b10);
        check("EX/MEM not writing",        1,  2,  1,   0,   4,   1,   2'b00, 2'b00);
        check("MEM/WB not writing",        1,  2,  3,   1,   1,   0,   2'b00, 2'b00);
        check("x0 never forwards (EM)",    0,  2,  0,   1,   4,   1,   2'b00, 2'b00);
        check("x0 never forwards (MW)",    0,  0,  3,   1,   0,   1,   2'b00, 2'b00);
        if (errors == 0) $display("forwarding_unit: PASS");
        else             $display("forwarding_unit: %0d errors", errors);
        $finish;
    end
endmodule
