`default_nettype none
//Drives the Basys 3 4-digit seven-segment display with a 16-bit hex value.
//
//All four digits share the same 7 segment wires; each digit has its own anode
//enable. So only one digit can be lit at a time. We cycle through them fast
//enough (each digit refreshed at ~380 Hz) that the eye sees all four at once:
//TIME MULTIPLEXING. Both segments and anodes are ACTIVE LOW on this board.
module sevenseg #(
    parameter REFRESH_BITS = 18 //2^16 cycles per digit = 0.66 ms at 100 MHz
)(
    input  wire        clk,
    input  wire [15:0] value,
    output reg  [6:0]  seg,  //seg[0] = segment a ... seg[6] = segment g
    output reg  [3:0]  an    //an[0] = rightmost digit
);

    reg [REFRESH_BITS-1:0] refresh = {REFRESH_BITS{1'b0}};
    always @(posedge clk) refresh <= refresh + 1'b1;

    //the top two bits of the free-running counter pick the digit
    wire [1:0] digit = refresh[REFRESH_BITS-1 -: 2];

    reg [3:0] nibble;
    always @(*) begin
        case (digit)
            2'd0: nibble = value[3:0];
            2'd1: nibble = value[7:4];
            2'd2: nibble = value[11:8];
            default: nibble = value[15:12];
        endcase
    end

    //hex digit -> segments, active high, bit 0 = a ... bit 6 = g
    reg [6:0] pattern;
    always @(*) begin
        case (nibble)
            4'h0: pattern = 7'h3F;  4'h1: pattern = 7'h06;
            4'h2: pattern = 7'h5B;  4'h3: pattern = 7'h4F;
            4'h4: pattern = 7'h66;  4'h5: pattern = 7'h6D;
            4'h6: pattern = 7'h7D;  4'h7: pattern = 7'h07;
            4'h8: pattern = 7'h7F;  4'h9: pattern = 7'h6F;
            4'hA: pattern = 7'h77;  4'hB: pattern = 7'h7C;
            4'hC: pattern = 7'h39;  4'hD: pattern = 7'h5E;
            4'hE: pattern = 7'h79;  default: pattern = 7'h71; //F
        endcase
    end

    //Register the outputs. Pins driven straight from a flop give clean,
    //glitch-free edges and easy I/O timing - a good default for any output.
    initial begin seg = 7'h7F; an = 4'hF; end
    always @(posedge clk) begin
        seg <= ~pattern;              //active low
        an  <= ~(4'b0001 << digit);   //active low, one digit at a time
    end

endmodule

`default_nettype wire
