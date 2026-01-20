module pc(
    input clk,
    input reset,
    //input [31:0] pc_in,
    output reg [31:0] pc_out
);

always @(posedge clk) begin
    if (reset) begin
        pc_out <= 32'b0;
    end else begin
        pc_out <= pc_out+4;
    end
end
endmodule