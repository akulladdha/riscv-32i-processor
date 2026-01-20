`timescale 1ns/1ps

module logic_test_tb();
    reg clk;
    reg [6:0] opcode;
    reg [31:0] addr;
    reg [31:0] write_data;

    wire reg_write, alu_src, mem_read, mem_write, mem_to_reg;
    wire [1:0] alu_op;

    wire [31:0] read_data;

    control_unit cu (
        .opcode(opcode),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_op(alu_op)
    );

    data_mem dm (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write), 
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        opcode = 0;
        addr = 0;
        write_data = 0;

        $dumpfile("logic_test.vcd");
        $dumpvars(0, logic_test_tb);

        // --- TEST 1: STORE WORD (SW) ---
        // Opcode for SW is 7'b0100011
        #10;
        opcode = 7'b0100011; 
        addr = 32'h00000004;
        write_data = 32'hDEADBEEF; 
        #10;
        
        // --- TEST 2: LOAD WORD (LW) ---
        // Opcode for LW is 7'b0000011
        #10;
        opcode = 7'b0000011;
        addr = 32'h00000004;
        #10;

        // --- TEST 3: R-TYPE (ADD) ---
        // Verify that memory signals turn OFF
        #10;
        opcode = 7'b0110011;
        #20;

        $display("Test Complete");
        $finish;
    end
endmodule