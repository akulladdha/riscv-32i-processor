module data_mem(
    input clk,
    input mem_read,
    input mem_write,
    input [31:0] addr,
    input [31:0] write_data,
    output [31:0] read_data
);

    reg [31:0] memory [0:1023];

    always @(posedge clk) begin
        if (mem_write) begin
            memory[addr[11:2]] <= write_data;
        end
    end

    assign read_data = (mem_read) ? memory[addr[11:2]] : 32'b0;

endmodule