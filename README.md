# Single-Cycle RISC-V Processor (RV32I Subset)

A 32-bit single-cycle processor implementing a subset of the RISC-V Instruction Set Architecture (ISA). This project was designed from scratch using Verilog and verified with GTKWave and IVerilog.

## 🚀 Overview
This processor executes instructions in a single clock cycle. It includes a complete datapath and control unit capable of handling arithmetic, logic, and memory operations.

### Supported Instructions
* **R-Type:** `ADD`
* **I-Type:** `ADDI`, `LW`
* **S-Type:** `SW`

## 🛠 Architecture
The design follows the classic Harvard Architecture, separating Instruction and Data memory.

```mermaid
graph TD
    %% Define Modules
    PC[Program Counter]
    IMEM[Instruction Memory]
    CU[Control Unit]
    RegFile[Register File]
    ALU[Arithmetic Logic Unit]
    DMEM[Data Memory]
    ImmGen[Immediate Generator]
    
    %% Muxes
    ALUMux{ALU Src Mux}
    WBMux{Writeback Mux}

    %% Logic Flow
    PC -->|addr| IMEM
    IMEM -->|32-bit instr| CU
    IMEM -->|bits 31:0| ImmGen
    IMEM -->|rs1, rs2, rd| RegFile

    CU -->|RegWrite| RegFile
    CU -->|ALUOp| ALU
    CU -->|ALUSrc| ALUMux
    CU -->|MemWrite/Read| DMEM
    CU -->|MemToReg| WBMux

    RegFile -->|data1| ALU
    RegFile -->|data2| ALUMux
    ImmGen -->|sign-extended imm| ALUMux

    ALUMux -->|operand B| ALU
    ALU -->|alu_result| DMEM
    ALU -->|alu_result| WBMux
    DMEM -->|read_data| WBMux

    WBMux -->|write_data| RegFile
    
    %% Style
    style PC fill:#f9f,stroke:#333,stroke-width:2px
    style CU fill:#fff4dd,stroke:#d4a017,stroke-width:2px
    style ALU fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    style DMEM fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
```

### Key Components:
* **Program Counter (PC):** Manages the execution flow.
* **Control Unit:** Decodes 7-bit opcodes to drive the datapath.
* **ALU:** Handles 10+ operations including arithmetic and bitwise logic.
* **Register File:** Supports 32 general-purpose registers (x0 hardwired to 0).
* **Data Memory:** 4KB of RAM for variable storage.

## 📊 Verification
The processor was verified using a custom testbench that executes a "Read-After-Write" program suite.

### Simulation Results
![Waveform Results](docs/gtkwave.png)
The waveform above demonstrates:
1. **Instruction Fetch:** Incrementing PC and valid hex instructions.
2. **ALU Accuracy:** Successful execution of `ADD` and `ADDI` operations.
3. **Memory Integrity:** Successful `SW` (Store) followed by `LW` (Load) to the same address.

## 💻 How to Run
1. Ensure `iverilog` and `gtkwave` are installed.
2. Compile the design:
   ```bash
   iverilog -o riscv_sim src/*.v test/top_tb.v
   vvp riscv_sim
   gtkwave riscv_processor.vcd
   ```