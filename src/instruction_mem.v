module instruction_mem (
    input  [31:0] addr, //From PC
    output [31:0] instruction //To Control/Reg
);

    reg [31:0] memory [0:1023];
    
    initial begin
        $readmemh("sample_program.hex", memory);
    end

    assign instruction = memory[addr >> 2]; //converts from the address to the word index

endmodule