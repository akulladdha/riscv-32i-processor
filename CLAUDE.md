# CLAUDE.md

Working notes for a 5-stage pipelined RV32I processor in Verilog-2001.
Rewritten 2026-11-12 from a full read of the RTL at commit `c83428f`, with the
test suite run on this machine (15/15 pass). Where any doc and the RTL
disagree, the RTL wins.

Companion docs — read these rather than duplicating them here:

| File | Contents |
|---|---|
| `README.md` | Public-facing overview |
| `COVERAGE.md` | Opcode and hazard coverage matrices, mutation-test results |
| `errors_fixed.md` | Log of every bug fixed: evidence before, change, evidence after |
| `next_steps.md` | Phased Basys 3 roadmap (Phase 0 LED blink → Phase 5 ILA bring-up) |

---

## Session goal (current)

The owner knows computer architecture and is here to learn **Verilog and RTL
design practice**, then take the core to a **Basys 3**. Work in this order:

1. Understand the code and the concepts behind each construct.
2. Implement the RTL cleanups in "Planned changes" below, one at a time, with
   the test suite green after each.
3. Build intuition for RTL from the basics — explain *what hardware* each
   construct infers, not just what it does in simulation.
4. Wire it to the board, following `next_steps.md`.

Teaching over doing: explain the why, prefer small reviewable changes, and let
the owner drive where they want to.

---

## Status at a glance

| | |
|---|---|
| ISA | 38 / 40 RV32I. Missing: `ECALL`, `EBREAK` (decode to silent NOP). `FENCE` is a NOP, which is legal here. |
| Tests | 15 self-checking tests, all passing (`bash tests/run_tests.sh`) |
| Hazards | Forwarding (EX/MEM, MEM/WB), write-first regfile, load-use stall, 2-deep flush |
| FPGA | **Not synthesizable to anything useful yet** — no output ports, async memories (Known Issues #1–#3) |
| Language | Plain Verilog-2001. No SystemVerilog constructs anywhere. |

---

## Module hierarchy

```
riscv_top                 src/riscv_top.v   (pipeline regs, imm-gen, ALU decode,
  |                                          forwarding, hazard, branch compare,
  |                                          load/store lane logic, WB mux — all inline)
  +-- pc               my_pc       src/pc.v
  +-- instruction_mem  my_imem     src/instruction_mem.v   (param PROGRAM)
  +-- control_unit     my_cu       src/control_unit.v
  +-- reg_file         my_regfile  src/register_file.v     (module/file names differ)
  +-- alu              my_alu      src/alu.v
  +-- data_mem         my_dmem     src/data_mem.v
```

`riscv_top` takes a `PROGRAM` parameter (default `"sample_program.hex"`) that is
passed to `instruction_mem`. Each test overrides it.

### Where things live in `src/riscv_top.v`

| Logic | Lines (approx.) |
|---|---|
| Branch comparator (`funct3` → `branch_cond`) | 92–101 |
| `branch_taken`, `jump_taken`, `redirect` / `flush` | 103–107 |
| PC next / load-use `stall` / PC mux | 109–119 |
| IF/ID register (flush clears, stall holds) | 134–143 |
| Immediate generation (I/S/B/U/J, priority `?:` chain) | 145–158 |
| ID/EX register (stall or flush → bubble) | 188–230 |
| ALU control decode (`alu_op` + `funct3`/`funct7`) | 233–266 |
| Forwarding unit | 270–287 |
| Operand muxes, branch/jump targets (JALR LSB clear) | 291–311 |
| EX/MEM register | 322–345 |
| Store byte-lane select (SB/SH replicate + byte enable) | 349–364 |
| Sub-word load extract and sign/zero extend | 379–390 |
| MEM/WB register, WB mux | 393–409 |

---

## Architecture as implemented

**Pipeline.** IF → ID → EX → MEM → WB, four clocked pipeline registers, all
`always @(posedge clk)` with synchronous reset. Signal names carry their stage
prefix (`id_ex_*`, `ex_mem_*`, …).

**Harvard.** `instruction_mem` and `data_mem` are separate arrays with separate
ports; IF and MEM never contend. IMEM is read-only (no write port, no clock),
initialized by `$readmemh(PROGRAM, …)`.

**Control.** `control_unit` decodes the **opcode only**, emitting `reg_write`,
`alu_src`, `mem_read`, `mem_write`, `mem_to_reg`, `branch`, `jump`, `jalr`,
`alu_op[1:0]`, `alu_a_src[1:0]`. It assigns defaults before its `case`, so it
infers no latches. The final 4-bit ALU operation is decoded **again** in EX from
`id_ex_alu_op` + `id_ex_funct3` + `id_ex_funct7[5]` — decode is split across two
stages (Planned change C).

`alu_op`: `00` add (loads/stores/LUI/AUIPC), `01` sub, `10` R-type decode,
`11` I-type decode. `alu_a_src`: `00` forwarded rs1, `01` PC (AUIPC, JAL/JALR
link), `10` zero (LUI).

**ALU.** 10 ops on a 4-bit code: ADD SUB AND OR XOR SLL SRL SRA SLT SLTU.
Shift amounts are masked to `b[4:0]`; SRA and SLT use `$signed`. The `zero`
output is no longer connected.

**Branches and jumps.** Resolved in EX. `branch_cond` compares the *forwarded*
operands by `funct3` (BEQ/BNE/BLT/BGE/BLTU/BGEU) with a dedicated comparator,
not the ALU. Jumps redirect unconditionally in EX. Link value `PC + 4` goes
through the ALU (`a = PC`, `b = 4`), so WB needs no extra mux. JALR target is
`(rs1 + imm) & ~1`. On redirect, IF/ID and ID/EX are cleared: 2-cycle penalty,
no prediction.

**Forwarding.** EX/MEM (priority) then MEM/WB, into both EX operands. Store
data is forwarded too (`ex_mem_reg_data2 <= ex_alu_b_reg`). JALR's target uses
the forwarded rs1 (`ex_fwd_rs1`).

**Register file.** Combinational read, `posedge` write, with a **write-first
bypass**: a read of the register being written that cycle returns the new
data. This closes the distance-3 RAW case that forwarding cannot reach. x0
reads as zero and ignores writes. All 32 registers reset to zero in a `for`
loop.

**Load-use stall.** If the EX instruction is a load whose `rd` matches ID's
`rs1` or `rs2`, freeze the PC, hold IF/ID, and bubble ID/EX. One cycle.

**Stall/flush priority.** IF/ID: flush beats stall. ID/EX: either clears. PC:
stall beats redirect — currently unreachable, since `stall` needs a load in EX
and `redirect` needs a branch/jump in EX.

**Memory access.** `data_mem` is 1024×32 (4 KB), word-indexed by `addr[11:2]`,
with a 4-bit byte-enable write. Stores replicate data across lanes
(`{4{byte}}`, `{2{half}}`) and the byte enable picks the lane, so the memory
has no shifter. Loads read the full word; `ex_mem_funct3` and `addr[1:0]`
select and extend the byte/halfword **in MEM**, before the MEM/WB register.

---

## Build & test

The whole suite, from the repo root, in **Git Bash**:

```bash
bash tests/run_tests.sh          # all 15
bash tests/run_tests.sh loads    # name filter
```

It assembles every `tests/progs/*.s` with `tests/asm.pl` (a small Perl RV32I
assembler), compiles each `tests/tb/*_tb.v` against `src/*.v`, runs it, and
tallies the results. It also runs the original `test/top_tb.v` as a regression.
Build output goes to `tests/build/` (gitignored, as are generated `.hex` files).

**Adding a test.** Write `tests/progs/<name>.s`, then
`tests/tb/<name>_tb.v` instantiating
`riscv_top #(.PROGRAM("tests/progs/<name>.hex"))` and using `chk(...)` /
`finish_test(...)` from `tests/tb/checker.vh`. Testbenches peek at
`dut.my_regfile.registers[n]` hierarchically, so **renaming the `my_regfile`
instance or the `registers` array breaks every test**.

Preconditions that are easy to forget:

- **Run from the repo root.** `$readmemh` paths resolve against the
  simulator's working directory. Run from anywhere else and IMEM silently
  fills with X.
- **Don't glob `test/*.v`.** The legacy unit testbenches in `test/` each have
  their own `initial` and `$dumpfile`. Compile one at a time, e.g.
  `iverilog -o alu_sim src/alu.v test/alu_tb.v && vvp alu_sim`. Most of them
  `$display` rather than self-check.
- **PowerShell doesn't expand `src\*.v`** for native executables. Use Git Bash,
  or `(Get-ChildItem src\*.v).FullName`.
- The `$readmemh ... Not enough words` warning is benign (short program in a
  1024-word array); the runner filters it out.

Waveforms: `gtkwave riscv_processor.vcd` after running `test/top_tb.v`.

---

## Toolchain

| Tool | Where |
|---|---|
| Icarus Verilog 12.0 (`iverilog`, `vvp`) | `C:\iverilog\bin` (on user PATH) |
| GTKWave | `C:\iverilog\gtkwave\bin` (on user PATH) |
| Perl (for `asm.pl`) | ships with Git Bash |
| Vivado | **not installed** — needed for the board phase |
| WSL2 | present, but has no tools installed; not needed |

Git: `core.autocrlf=true`, `.gitattributes` normalizes to LF,
`core.filemode=false`, and the identity is set repo-locally. Commit message
style: plain subjects, no filename prefix.

The repo sits inside OneDrive. Sync can race with simulator output and git
index writes; consider moving it to a local path.

`_attic/` holds stale macOS vvp binaries and an empty `riscv_top_tb.v`. It's
build junk kept out of caution and safe to delete.

---

## Planned changes (learning exercises, in suggested order)

Each one should leave `bash tests/run_tests.sh` at 15/15.

- **A. Extract inline logic into modules.** Pull `forwarding_unit`,
  `hazard_unit`, `imm_gen`, and `alu_decoder` out of `riscv_top.v` so the top
  level becomes wiring. Each gets a self-checking unit test.
- **B. Immediate generator as a `case`.** Replace the `?:` priority chain with
  `case (opcode)`. The cases are mutually exclusive, so the intent is a
  parallel mux, not a priority encoder.
- **C. Single-stage decode.** Have `control_unit` take `funct3`/`funct7` and
  emit the 4-bit `alu_control` directly. This removes `id_ex_alu_op` and
  `id_ex_funct7` from the ID/EX register.
- **D. Precise load-use stall.** Only compare `id_rs2` when the ID instruction
  actually reads rs2 (R, S, B), and `id_rs1` when it reads rs1 (not
  LUI/AUIPC/JAL). Today the comparison is spurious for I/U/J-type instructions,
  which costs cycles but never gives a wrong answer.
- **E. Illegal-instruction signal.** Flag unknown opcodes, plus ECALL/EBREAK,
  instead of running them as silent NOPs. Optionally implement ECALL/EBREAK as
  a halt, which also gives the core a defined stop condition.
- **F. Hygiene.** Rename `register_file.v` → `reg_file.v` (or the module), pick
  one array declaration direction, slice IMEM with `addr[11:2]` like DMEM
  does, and drop the unused ALU `zero` port.
- **G. Register file without reset** (so it can infer LUTRAM). Do this as part
  of the FPGA work; see Known Issue #4.

---

## Known issues

Tags: **[FPGA blocker]**, **[latent]**, **[hygiene]**.

1. **[FPGA blocker] No output ports.** `riscv_top` has only `clk` and `rst`, so
   synthesis will optimize the entire CPU away. Needs observable I/O (LEDs,
   seven-segment, UART via memory-mapped I/O) and an `.xdc`. See
   `next_steps.md` Phases 0, 1, and 4.
2. **[FPGA blocker] IMEM reads combinationally** (`instruction_mem.v`, the
   `assign`), and the module has no clock, so it can't infer BRAM. Making it
   synchronous changes the IF stage: the BRAM output register becomes IF/ID,
   so flush/stall must drive the BRAM's enable/reset or a kill-mux. See
   `next_steps.md` Phase 2.
3. **[FPGA blocker] DMEM reads combinationally and through a gate** —
   `assign read_data = mem_read ? memory[addr[11:2]] : 0`. Both the async read
   and the output mux defeat BRAM inference. When it becomes synchronous, the
   load-extract logic (riscv_top.v ~379–390) must move from MEM to WB, and
   `funct3` + `addr[1:0]` must be added to MEM/WB.
4. **[FPGA cost] Register-file reset forces flip-flops.** The `for`-loop reset
   puts 1024 bits in FFs rather than LUTRAM. Acceptable on an XC7A35T, but
   your reset strategy is choosing the memory primitive.
5. **[FPGA timing] Long branch-resolve path.** Forwarding mux → 32-bit
   comparator → target adder → PC mux → PC, plus the async IMEM read feeding
   IF/ID. Expect a modest Fmax; plan on a divided clock first.
6. **[latent] ECALL/EBREAK/unknown opcodes run as silent NOPs**
   (`control_unit.v` empty `default`). See Planned change E.
7. **[latent] No halt; fetch runs past the program.** Uninitialized IMEM words
   are X in simulation. These are harmless only because the decoder's defaults
   keep `reg_write = 0`. On hardware the core will run whatever the BRAM
   initializes to. Tests stop on a fixed `#delay`.
8. **[latent] Spurious load-use stalls.** The stall checks `rs1`/`rs2` fields
   for every format. See Planned change D.
9. **[latent] Stall outranks redirect in the PC mux** (`riscv_top.v:119`).
   Unreachable today. It becomes live if anything ever makes a load and a
   redirect coincide in EX.
10. **[hygiene] Monolithic top level, split decode, naming mismatches.** See
    Planned changes A, C, F. Also, MEM/WB carries both the ALU result and the
    load data plus a select (65 bits) where one resolved 32-bit value would do.
11. **[hygiene] `$readmemh` uses a relative path.** It depends on the working
    directory in simulation. For Vivado, the `.hex` must be added to the
    project as a design source.

Fixed issues (the old #1–#5: distance-3 RAW, I-type running as ADDI, all
branches running as BEQ, word-only memory, missing LUI/AUIPC/JAL/JALR) are
documented in `errors_fixed.md`.
