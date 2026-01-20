module reg_file (
    input clk,
    input rst,
    input rg_write_en,// Write Enable: only write if this is 1
    input [4:0] rg_des_addr,// Destination register index (0-31)
    input [4:0] rg_sr1_addr,// Source 1 register index (0-31)
    input [4:0] rg_sr2_addr,// Source 2 register index (0-31)
    input [31:0] rg_des_data,// Data to be written
    output [31:0] rg_sr1_data,// Data read from Source 1
    output [31:0] rg_sr2_data// Data read from Source 2
);
reg [31:0] registers [31:0];
integer i;

assign rg_sr1_data = (rg_sr1_addr == 5'b0) ? 32'b0 : registers[rg_sr1_addr];
assign rg_sr2_data = (rg_sr2_addr == 5'b0) ? 32'b0 : registers[rg_sr2_addr];

always @(posedge clk) begin
    if(rst) begin
        for(i=0;  i<32; i=i+1)begin
            registers[i] <=32'b0;
        end
    end 
    else if (rg_write_en && (rg_des_addr!=5'b0)) begin
            registers[rg_des_addr] <= rg_des_data;
    end
end



endmodule