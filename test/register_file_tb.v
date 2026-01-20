`timescale 1ns/1ps
module register_file_tb();
    reg clk;
    reg rst;
    reg rg_write_en;
    reg [4:0] rg_des_addr;
    reg [4:0] rg_sr1_addr;
    reg [4:0] rg_sr2_addr;
    reg [31:0] rg_des_data;
    wire [31:0] rg_sr1_data;
    wire [31:0] rg_sr2_data;

reg_file uut (
    .clk(clk),
    .rst(rst),
    .rg_write_en(rg_write_en),
    .rg_des_addr(rg_des_addr),
    .rg_sr1_addr(rg_sr1_addr),
    .rg_sr2_addr(rg_sr2_addr),
    .rg_des_data(rg_des_data),
    .rg_sr1_data(rg_sr1_data),
    .rg_sr2_data(rg_sr2_data)
);

    initial begin
        $dumpfile("register_file_test.vcd");
        $dumpvars(0, register_file_tb);
        clk = 0;
    end
    always #5 clk = ~clk;

    initial begin //stimulus
        rst = 1;
        rg_write_en = 0;
        rg_des_addr = 5'b00001;
        rg_sr1_addr = 5'b00010;
        rg_sr2_addr = 5'b00011;
        rg_des_data = 32'hDEADBEEF;
        #10;

        rst = 0;
        rg_write_en = 1;
        rg_des_addr = 5'b00001; // Write to register 1
        rg_des_data = 32'hDEADBEEF;
        #10;

        rg_sr1_addr = 5'b00001; // Read from register 1
        rg_sr2_addr = 5'b00010; // Read from register 2 (should be 0)
        #10;

        $display("Register 1 Data: %h", rg_sr1_data);
        $display("Register 2 Data: %h", rg_sr2_data);
        $finish;
    end
endmodule