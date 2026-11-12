`default_nettype none
//Conditions one asynchronous input (a button or switch) for use in the clk
//domain: synchronize, debounce, and detect the rising edge.
//
//1. SYNCHRONIZE. The pin changes with no relation to clk. If it changes just
//   as a flop samples it, that flop can go METASTABLE - hover between 0 and 1
//   for an unbounded time. A second flop gives it a full cycle to resolve
//   before anything else looks at it. Simulation never shows metastability;
//   real hardware fails intermittently without this.
//2. DEBOUNCE. A mechanical contact bounces for a few ms when pressed. Accept a
//   new level only after the input has held it for STABLE_CYCLES.
//3. EDGE DETECT. One press must produce one single-cycle pulse, not millions.
module input_conditioner #(
    parameter STABLE_CYCLES = 1_000_000 //10 ms at 100 MHz; tiny in simulation
)(
    input  wire clk,
    input  wire in_async,
    output reg  level,   //debounced, synchronized level
    output wire rise     //one-cycle pulse on each debounced 0->1 transition
);

    //Initial values: legal on Xilinx FPGAs (flops are loaded from the
    //bitstream at configuration), NOT on ASICs. Used here so the inputs are
    //defined before any reset exists.
    initial level = 1'b0;
    reg [1:0] sync    = 2'b00;
    reg       level_d = 1'b0;

    localparam CW = (STABLE_CYCLES > 1) ? $clog2(STABLE_CYCLES) : 1;
    reg [CW-1:0] count = {CW{1'b0}};

    always @(posedge clk) begin
        sync <= {sync[0], in_async};             //2-flop synchronizer

        if (sync[1] == level)
            count <= {CW{1'b0}};                 //no change pending: restart
        else if (count == STABLE_CYCLES - 1) begin
            level <= sync[1];                    //held long enough: accept
            count <= {CW{1'b0}};
        end else
            count <= count + 1'b1;               //still bouncing or not yet stable

        level_d <= level;
    end

    assign rise = level & ~level_d;

endmodule

`default_nettype wire
