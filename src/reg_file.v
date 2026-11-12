`default_nettype none
module reg_file (
    input  wire clk,
    input  wire rst,
    input  wire rg_write_en,// Write Enable: only write if this is 1
    input  wire [4:0] rg_des_addr,// Destination register index (0-31)
    input  wire [4:0] rg_sr1_addr,// Source 1 register index (0-31)
    input  wire [4:0] rg_sr2_addr,// Source 2 register index (0-31)
    input  wire [31:0] rg_des_data,// Data to be written
    output wire [31:0] rg_sr1_data,// Data read from Source 1
    output wire [31:0] rg_sr2_data,// Data read from Source 2
    input  wire [4:0]  dbg_addr,   // Debug read port: observation only
    output wire [31:0] dbg_data
);
//[0:31]: ascending index range, matching the memories
reg [31:0] registers [0:31];
integer i;

// Write-first: a read in the same cycle as a write to the same register must
// return the new data. Without this, a RAW dependency at distance 3 - past the
// reach of EX/MEM and MEM/WB forwarding - reads a stale value.
wire wr_active = rg_write_en && (rg_des_addr != 5'b0);

assign rg_sr1_data = (rg_sr1_addr == 5'b0) ? 32'b0 :
                     (wr_active && (rg_des_addr == rg_sr1_addr)) ? rg_des_data :
                     registers[rg_sr1_addr];
assign rg_sr2_data = (rg_sr2_addr == 5'b0) ? 32'b0 :
                     (wr_active && (rg_des_addr == rg_sr2_addr)) ? rg_des_data :
                     registers[rg_sr2_addr];

// Debug port: a third, independent read port (one more 32:1 mux). It reads the
// array directly, WITHOUT the write-first bypass, so it shows committed state.
assign dbg_data = (dbg_addr == 5'b0) ? 32'b0 : registers[dbg_addr];

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

`default_nettype wire
