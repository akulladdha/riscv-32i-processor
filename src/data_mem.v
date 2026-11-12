`default_nettype none
module data_mem(
    input  wire clk,
    input  wire mem_read,
    input  wire mem_write,
    input  wire [3:0] byte_en, //per-lane write enable, for SB and SH
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);

    reg [31:0] memory [0:1023];

    always @(posedge clk) begin
        if (mem_write) begin
            if (byte_en[0]) memory[addr[11:2]][7:0]   <= write_data[7:0];
            if (byte_en[1]) memory[addr[11:2]][15:8]  <= write_data[15:8];
            if (byte_en[2]) memory[addr[11:2]][23:16] <= write_data[23:16];
            if (byte_en[3]) memory[addr[11:2]][31:24] <= write_data[31:24];
        end
    end

    assign read_data = (mem_read) ? memory[addr[11:2]] : 32'b0;

endmodule

`default_nettype wire
