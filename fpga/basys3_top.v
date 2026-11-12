`default_nettype none
//Basys 3 board wrapper for riscv_top.
//
//  btnC      reset
//  btnU      single-step: one CPU clock per press (when sw[15] is off)
//  sw[15]    run: the CPU steps automatically at ~12 Hz
//  sw[4:0]   register to display, x0..x31
//  sw[5]     display the PC instead of a register
//  sw[6]     display the upper 16 bits instead of the lower 16
//  7-seg     16 bits of the selected value, hex
//  led[15]   halted        led[14]  error (illegal instruction)
//  led[13]   run mode      led[7:0] PC word index (PC[9:2])
//
//Clocking: everything runs on the single 100 MHz board clock. The CPU is
//slowed with a CLOCK ENABLE, never with a divided clock: a clock made by logic
//leaves the FPGA's dedicated low-skew clock network, and the flops it drives
//no longer switch together. One clock, enables everywhere, is the rule.
module basys3_top #(
    parameter PROGRAM         = "demo.hex",
    parameter DEBOUNCE_CYCLES = 1_000_000, //10 ms
    parameter RUN_DIV_BITS    = 23,        //2^23 / 100 MHz = 84 ms per step
    parameter REFRESH_BITS    = 18
)(
    input  wire        clk,   //100 MHz, pin W5
    input  wire        btnC,
    input  wire        btnU,
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an
);

    //---------------- reset ----------------
    //Power-on reset: hold the CPU in reset for the first 15 cycles after the
    //FPGA is configured, so it starts clean without a button press. Relies on
    //the counter's initial value from the bitstream.
    reg [3:0] por_count = 4'd0;
    wire      por = ~&por_count;
    always @(posedge clk) if (por) por_count <= por_count + 1'b1;

    //The reset button only needs synchronizing, not debouncing: a bouncing
    //reset just resets a few more times.
    reg [1:0] btnC_sync = 2'b00;
    always @(posedge clk) btnC_sync <= {btnC_sync[0], btnC};

    wire rst = por | btnC_sync[1];

    //---------------- switches ----------------
    //Each switch is synchronized by its own 2-flop chain. That is only valid
    //because the switches are INDEPENDENT signals. A multi-bit value that
    //changes as a unit (a counter, a bus) must never be synchronized bit by
    //bit - the bits can resolve on different cycles and form a value that
    //never existed. That needs Gray code or a handshake instead.
    reg [15:0] sw_meta = 16'b0, sw_s = 16'b0;
    always @(posedge clk) begin
        sw_meta <= sw;
        sw_s    <= sw_meta;
    end
    wire run_mode = sw_s[15];

    //---------------- clock enable ----------------
    wire step_pulse;
    input_conditioner #(.STABLE_CYCLES(DEBOUNCE_CYCLES)) step_btn (
        .clk(clk), .in_async(btnU), .level(), .rise(step_pulse)
    );

    //free-running divider: one tick every 2^RUN_DIV_BITS cycles
    reg [RUN_DIV_BITS-1:0] run_div = {RUN_DIV_BITS{1'b0}};
    always @(posedge clk) run_div <= run_div + 1'b1;
    wire run_tick = &run_div;

    wire cpu_ce = run_mode ? run_tick : step_pulse;

    //---------------- the CPU ----------------
    wire [31:0] dbg_reg_data, dbg_pc;
    wire        halted, error;

    riscv_top #(.PROGRAM(PROGRAM)) cpu (
        .clk(clk),
        .rst(rst),
        .ce(cpu_ce),
        .dbg_reg_sel(sw_s[4:0]),
        .dbg_reg_data(dbg_reg_data),
        .dbg_pc(dbg_pc),
        .halted(halted),
        .error(error)
    );

    //---------------- outputs ----------------
    wire [31:0] shown         = sw_s[5] ? dbg_pc : dbg_reg_data;
    wire [15:0] display_value = sw_s[6] ? shown[31:16] : shown[15:0];

    sevenseg #(.REFRESH_BITS(REFRESH_BITS)) display (
        .clk(clk), .value(display_value), .seg(seg), .an(an)
    );
    assign dp = 1'b1; //decimal point off (active low)

    assign led[15]   = halted;
    assign led[14]   = error;
    assign led[13]   = run_mode;
    assign led[12:8] = 5'b0;
    assign led[7:0]  = dbg_pc[9:2];

endmodule

`default_nettype wire
