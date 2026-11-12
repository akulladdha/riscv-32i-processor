`default_nettype none
module instruction_mem #(
    parameter PROGRAM = "sample_program.hex"
) (
    input  wire [31:0] addr, //From PC
    output wire [31:0] instruction //To Control/Reg
);

    reg [31:0] memory [0:1023];
    
    initial begin
        $readmemh(PROGRAM, memory);
    end

    //addr[11:2] is the word index: drop the 2 byte-offset bits, keep the 10 bits
    //a 1024-word array needs. "addr >> 2" would be a 30-bit index into a
    //1024-entry array - out-of-range reads are X in simulation, and it hides
    //the intent from both readers and synthesis. Addresses above 0xFFF alias.
    assign instruction = memory[addr[11:2]];

endmodule

`default_nettype wire
