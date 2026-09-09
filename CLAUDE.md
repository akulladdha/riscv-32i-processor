# CLAUDE.md

Working notes for a 5-stage pipelined RV32I-subset processor. Written from a
full read of the RTL on 2026-09-09. Findings cite file and line. Where the
README and the RTL disagree, the RTL wins and the disagreement is recorded.

Icarus Verilog 12.0 was installed during the audit, so the integration test and
the headline bugs below are **verified by execution**, not inferred. Findings
carrying a "Reproduced" note were run on this machine.

---

## Project Overview

A 32-bit, 5-stage, in-order pipelined processor in plain Verilog-2001 (not
SystemVerilog, despite the repo description — no `logic`, `always_ff`, or
`typedef` appears anywhere). Originally developed on macOS with MacPorts
iverilog + GTKWave, then copied to Windows.

Stated target hardware is a Basys 3 (Artix-7 XC7A35T). **Nothing in this repo
targets an FPGA.** There is no `.xdc`, no `.xpr`, no TCL, no bitstream flow,
and the top module has no I/O ports. The FPGA target is an aspiration, not an
implemented flow. See Known Issues #8.

The implemented ISA is far smaller than "RV32I". Eight instructions work:
`ADD SUB AND OR ADDI LW SW BEQ`. The rest of RV32I is either absent or, worse,
silently mis-executes (Known Issues #2–#5).

---

## Architecture As Implemented

### Harvard check

| Question | Answer |
|---|---|
| IMEM and DMEM separate, independent ports? | **Yes.** `instruction_mem` (riscv_top.v:108) and `data_mem` (riscv_top.v:286) are distinct modules with distinct arrays and no shared port. |
| Can IF and MEM both access memory in the same cycle? | **Yes.** IF drives IMEM from `pc_out`; MEM drives DMEM from `ex_mem_alu_result`. No arbitration, no structural hazard. |
| IMEM synchronous-read (BRAM-inferrable)? | **No.** `assign instruction = memory[addr >> 2]` — instruction_mem.v:12 is combinational. The module has no clock port at all. |
| DMEM synchronous-read (BRAM-inferrable)? | **No.** `assign read_data = (mem_read) ? memory[addr[11:2]] : 32'b0` — data_mem.v:18 is combinational *and* gated by `mem_read`. Writes are synchronous (data_mem.v:12–16); reads are not. |
| Can a store reach instruction memory? | **No.** `instruction_mem` has no write port and no clock (instruction_mem.v:1–4). Contents come only from `$readmemh` at elaboration (instruction_mem.v:9). Instruction memory is genuinely read-only. |

The Harvard split is real and correct. The memory *style* is the problem, not
the topology — see Known Issues #6 and #7.

### Pipeline check

| Item | Status | Location |
|---|---|---|
| IF/ID clocked register | **Present** | riscv_top.v:114–124 |
| ID/EX clocked register | **Present** | riscv_top.v:161–199 |
| EX/MEM clocked register | **Present** | riscv_top.v:258–284 |
| MEM/WB clocked register | **Present** | riscv_top.v:296–310 |
| Forwarding EX/MEM → EX | **Present** | riscv_top.v:222, 230 (select); 238, 242 (mux) |
| Forwarding MEM/WB → EX | **Present** | riscv_top.v:225, 232 (select); 239, 243 (mux) |
| Store-data forwarding into MEM | **Present** | riscv_top.v:276 — `ex_mem_reg_data2 <= ex_alu_b_reg` captures the *forwarded* rs2, not the stale `id_ex_reg_data2`. Correct. |
| Load-use stall | **Present and correct** | Detect riscv_top.v:94–96; PC frozen riscv_top.v:99; IF/ID held riscv_top.v:119 (`else if (!stall)`); ID/EX bubbled riscv_top.v:162. All three actions present. |
| Branch resolution stage | **EX** | riscv_top.v:86 — `branch_taken = id_ex_branch && ex_zero` |
| Flush depth | **2, and it kills the right stages** | riscv_top.v:115 zeroes IF/ID (kills the instruction in IF); riscv_top.v:162 zeroes ID/EX (kills the instruction in ID). The branch itself is in EX and completes. Verified by hand-trace against `sample_program.hex`. |
| Register file same-cycle write/read | **ABSENT — this is a real bug** | register_file.v:15–16 read combinationally from the array; register_file.v:24–26 write on `posedge clk`. No write-first transparency, no internal bypass. See Known Issues #1. |
| x0 hardwired on read | **Present** | register_file.v:15–16 — both read ports mux to `32'b0` when the address is 0. |
| x0 hardwired on write | **Present** | register_file.v:24 — `rg_write_en && (rg_des_addr != 5'b0)`. |
| Reset consistency | **Consistent — all synchronous** | pc.v:8–13, register_file.v:18–23, and all four pipeline registers (riscv_top.v:115, 162, 259, 297) use `always @(posedge clk)` with no reset in the sensitivity list. Uniformly sync. This is the Xilinx-preferred style; no issue here. |
| Inferred latches | **None** | `control_unit` assigns all seven outputs unconditionally before its `case` (control_unit.v:13–19). `alu` has a `default` (alu.v:23). The ALU-control decoder has `default` at both levels (riscv_top.v:211, 214). The forwarding block is a complete if/else-if/else chain (riscv_top.v:220–236). Every combinational output is assigned on every path. |
| Combinational loops | **None** | The only feedback path is `pc_out → if_pc_plus4 → pc_next → pc_in_mux → pc`, broken by the clocked register in pc.v:8. `branch_taken` derives from `id_ex_branch` (a register) and `ex_zero` (ALU output of registered/forwarded operands). No loop. |

### Branch mechanism, in detail

Resolution is early — in EX, off `id_ex_branch` rather than `ex_mem_branch`
(riscv_top.v:86, with the design comment at riscv_top.v:83–85). The EX/MEM stage
*does* latch `ex_mem_branch`, `ex_mem_zero`, and `ex_mem_branch_target`
(riscv_top.v:270, 263, 261) but **nothing ever reads them** — dead registers left
over from a later-resolution design. Synthesis will trim them; they mislead a
reader. See Known Issues #12.

The branch target is `id_ex_pc + id_ex_imm_ext` (riscv_top.v:247) — branch PC
plus the B-immediate, which is correct. B-immediate assembly at
riscv_top.v:129–130 is correct, including the implicit trailing zero.

The PC mux priority is `stall ? pc_out : (branch_taken ? target : pc+4)`
(riscv_top.v:91, 99) — **stall outranks branch_taken**. If both asserted, the
branch target would be silently dropped. Today this is unreachable, because
`stall` requires `id_ex_mem_read` and `branch_taken` requires `id_ex_branch`,
and one instruction cannot be both. It is latent, not live. See Known Issues #17.

### ISA coverage

Present and believed correct: `ADD`, `SUB`, `AND`, `OR` (R-type,
control_unit.v:21–25 plus ALU decode riscv_top.v:206–213); `ADDI`
(control_unit.v:26–30); `LW` (control_unit.v:31–38); `SW` (control_unit.v:40–47);
`BEQ` (control_unit.v:48–56).

Absent — decoded by `default` (control_unit.v:59–61) into an all-zero control
word, i.e. **silently executed as a NOP with no error**:
`LUI`, `AUIPC`, `JAL`, `JALR`, `FENCE`, `ECALL`, `EBREAK`.

Absent — the opcode *is* matched but `funct3` is ignored, so these execute as
**the wrong instruction, silently**:

- All of `SLLI SRLI SRAI SLTI SLTIU XORI ORI ANDI` execute as `ADDI`.
- All of `SLL SRL SRA SLT SLTU XOR` execute as `ADD` (ALU decode default,
  riscv_top.v:211).
- All of `BNE BLT BGE BLTU BGEU` execute as `BEQ`.
- All of `LB LH LBU LHU` execute as `LW`; `SB SH` execute as `SW`.

On the specific items asked about:

- **JALR LSB clear** — not applicable; `JALR` is not implemented. There is no
  `& ~32'b1` or equivalent anywhere in the source. Opcode `1100111` falls to the
  `default` NOP.
- **AUIPC** — not implemented. Opcode `0010111` falls to the `default` NOP.
  `id_ex_pc` is piped to EX (riscv_top.v:181) and would be available, but nothing
  uses it for an AUIPC path.
- **LB/LH sign-extension vs LBU/LHU** — no sub-word memory access exists at all.
  `data_mem` is word-only: writes `memory[addr[11:2]]` (data_mem.v:14), reads the
  same (data_mem.v:18). There is no byte enable, no `funct3` input to the memory,
  and no sign/zero-extension logic on the load path. `id_ex_funct3` is piped as
  far as EX (riscv_top.v:189) and then dropped — it never reaches MEM or WB.
- **SLT vs SLTU** — neither implemented. Note the commented-out draft at alu.v:20
  uses `(a < b)`, which on Verilog `[31:0]` operands is an **unsigned** compare —
  that would have been `SLTU` semantics under an `SLT` label. If that line is ever
  revived it needs `$signed(a) < $signed(b)` for `SLT`.
- **Shift-amount masking** — no shifts implemented. The commented-out draft at
  alu.v:21–22 does mask correctly with `b[4:0]`, but implements only `SLL`/`SRL`;
  there is no `SRA` (which needs `$signed(a) >>> b[4:0]`).

The ALU physically supports four operations (alu.v:10–24). Six more are present
but commented out (alu.v:17–22).

---

## Module Hierarchy

```
riscv_top                 src/riscv_top.v        (all 4 pipeline regs, fwd unit,
  |                                               hazard unit, imm-gen, ALU-ctrl,
  |                                               WB mux — all inline)
  +-- pc               my_pc       src/pc.v
  +-- instruction_mem  my_imem     src/instruction_mem.v
  +-- control_unit     my_cu       src/control_unit.v
  +-- reg_file         my_regfile  src/register_file.v   (module is reg_file,
  |                                                       file is register_file.v)
  +-- alu              my_alu      src/alu.v
  +-- data_mem         my_dmem     src/data_mem.v
```

Everything not in that list — forwarding unit, hazard-detection unit, immediate
generator, ALU control decoder, writeback mux, branch logic — lives inline in
`riscv_top.v`, not as separate modules. The README's stage table implies more
modularity than exists.

Testbench-to-DUT map:

```
test/top_tb.v            -> riscv_top          (integration; module riscv_top_tb)
test/alu_tb.v            -> alu
test/pc_tb.v             -> pc
test/register_file_tb.v  -> reg_file
test/fetch_stage_tb.v    -> pc + instruction_mem
test/logic_test_tb.v     -> control_unit + data_mem
```

---

## File Map

| Path | Role |
|---|---|
| `src/riscv_top.v` | Top level. Pipeline registers, forwarding, hazards, imm-gen. 314 lines; the bulk of the design. |
| `src/pc.v` | Program counter register. Sync reset. |
| `src/instruction_mem.v` | 1024x32 ROM, `$readmemh` init, **combinational read**. |
| `src/data_mem.v` | 1024x32 RAM, sync write, **combinational gated read**. 4 KB. |
| `src/register_file.v` | 32x32 regfile. Module name is `reg_file`. Comb read, sync write, **no write-first bypass**. |
| `src/alu.v` | 4 ops live (ADD/SUB/AND/OR), 6 commented out. |
| `src/control_unit.v` | Opcode-only decoder. Ignores `funct3`/`funct7` entirely. |
| `test/top_tb.v` | Integration test — the one that matters. Self-checking, 4 assertions. |
| `test/{alu,pc,register_file,fetch_stage,logic_test}_tb.v` | Unit testbenches. Mostly `$display` plus waveform rather than self-checking. |
| `sample_program.hex` | 5-instruction BEQ/hazard program. Read by `instruction_mem` via a **relative** path. |
| `docs/riscvdatapath.png`, `docs/gtkwave.png` | README figures. |
| `_attic/` | Quarantined during this audit. Not deleted. See below. |
| `.gitignore`, `.gitattributes` | Added by this audit. |

### `sample_program.hex`, decoded

```
addr  word      instruction              note
0x00  00500093  ADDI x1, x0, 5
0x04  00500113  ADDI x2, x0, 5
0x08  00208463  BEQ  x1, x2, +8          -> target 0x10; taken (5 == 5)
0x0C  06300193  ADDI x3, x0, 99          -> must be flushed
0x10  02A00213  ADDI x4, x0, 42
```

Expected: `x1=5, x2=5, x3=0, x4=42`. This matches the README and matches
`test/top_tb.v:26–44`. Words 5..1023 of IMEM are never initialized, so once the
PC runs past `0x10` the fetched instruction is `32'bx`. That is benign here:
`control_unit` assigns all-zero defaults before its `case` (control_unit.v:13–19),
so an X opcode yields `reg_write = 0` and cannot corrupt architectural state.

### `_attic/` contents

Moved, not deleted, because they fall outside the delete whitelist:

- `_attic/riscv_sim`, `_attic/sim/{alu,fetch,logic,pc,reg,riscv}_sim` — compiled
  vvp images. Each begins `#!/opt/local/bin/vvp`, a MacPorts path that does not
  exist on this machine. They were tracked in git. Pure build output; safe to
  delete permanently.
- `_attic/test/riscv_top_tb.v` — a 0-byte file. The real integration testbench is
  `test/top_tb.v`, which confusingly declares `module riscv_top_tb`. The empty
  file was an orphan and shadowed nothing.

---

## Build & Simulation Flow

The only entry point is the README's command block. There is **no Makefile, no
shell script, and no TCL** in this repo — nothing automates the build.

```bash
iverilog -o riscv_sim src/*.v test/top_tb.v
vvp riscv_sim
gtkwave riscv_processor.vcd     # optional
```

Two unstated preconditions:

1. It must be run **from the repo root**. `instruction_mem.v:9` calls
   `$readmemh("sample_program.hex", memory)` with a relative path, resolved
   against the simulator's working directory, not the source file's location.
   Run it from anywhere else and IMEM silently fills with X.
2. Compile `test/top_tb.v` specifically, **not** `test/*.v`. The unit testbenches
   each carry their own `initial` block and `$dumpfile`; globbing them together
   gives multiple top-level modules racing on one VCD.

Unit testbenches follow the same pattern, e.g.
`iverilog -o alu_sim src/alu.v test/alu_tb.v && vvp alu_sim`.

**Actual output of the integration test** (run on this machine, Icarus Verilog
12.0, exit 0):

```
WARNING: src/instruction_mem.v:9: $readmemh(sample_program.hex): Not enough
         words in the file for the requested range [0:1023].
VCD info: dumpfile riscv_processor.vcd opened for output.
PASS: BEQ skipped the ADDI to x3 and executed the ADDI to x4.
test/top_tb.v:47: $finish called at 215000 (1ps)
```

**The test passes.** The `$readmemh` warning is expected and benign — the
program is 5 words and the array is 1024 deep (Known Issues #10).

The mechanism, confirmed against the waveform: at cycle 5 the BEQ is in EX with
`x1` forwarded from MEM/WB (`forward_a = 2'b01`) and `x2` from EX/MEM
(`forward_b = 2'b10`); the ALU computes `5 - 5 = 0`; `ex_zero` asserts; flush
zeroes IF/ID and ID/EX, killing the `ADDI x3` in ID and the `ADDI x4` in IF; the
PC redirects to `0x10` and re-fetches `ADDI x4`. `x3` is never written, `x4`
becomes 42. The test should pass.

Note what that test does *not* cover: it exercises only distance-1 and
distance-2 forwarding. It never constructs a distance-3 dependency, which is
exactly why Known Issues #1 has survived undetected.

---

## Toolchain Notes (WSL2 vs Windows)

State of this machine after the audit:

| Tool | Windows | WSL2 (Ubuntu) |
|---|---|---|
| `iverilog` | **12.0, installed** — `C:\iverilog\bin\iverilog.exe` | absent |
| `vvp` | **12.0, installed** — `C:\iverilog\bin\vvp.exe` | absent |
| `gtkwave` | **installed** — `C:\iverilog\gtkwave\bin\gtkwave.exe` | absent |
| `make` | absent | not checked |
| Vivado | absent | absent |

Installed during the audit with:

```powershell
winget install --id Icarus.Verilog --source winget `
  --accept-source-agreements --accept-package-agreements --silent
```

That pulls `iverilog-v12-20220611-x64_setup.exe` from bleyer.org, which bundles
GTKWave. **The silent install does not touch PATH** — `C:\iverilog\bin` and
`C:\iverilog\gtkwave\bin` were appended to the *user* PATH manually (no admin
required). A new shell is needed to pick that up.

Note for reproducing the earlier state: `winget` without
`--accept-source-agreements` blocks on an interactive `msstore` prompt, and
WSL2's `sudo` needs an interactive password — which is why neither worked
unattended before you asked.

Recommended, in order of least friction:

1. **Native Windows — the right default for this repo.** Install Icarus Verilog
   for Windows; it bundles GTKWave. There is no reason to reach for a Unix
   environment here: this project has no Makefile, no shell script, and no TCL
   (Known Issues #15). The whole build is three `iverilog`/`vvp` invocations, and
   nothing in it is POSIX-specific. Native also keeps the repo on its own
   filesystem and gives you a native GTKWave with no display bridge.

   One wrinkle: **PowerShell does not expand wildcards for native executables.**
   It hands `src\*.v` to the process literally (verified on this machine). Two
   ways around it:

   ```powershell
   # PowerShell — expand the glob yourself
   iverilog -o riscv_sim (Get-ChildItem src\*.v).FullName test\top_tb.v
   vvp riscv_sim
   ```

   ```bash
   # Git Bash (already installed here) — the README command works verbatim
   iverilog -o riscv_sim src/*.v test/top_tb.v
   vvp riscv_sim
   ```

   `cmd.exe` expands nothing either; don't use it. Either way, run from the repo
   root — see the `$readmemh` note in Build & Simulation Flow.

2. **WSL2** — `sudo apt update && sudo apt install iverilog gtkwave`. A
   reasonable choice if you already live in WSL, but it is *not* the lower-friction
   option for this repo, and the "closer to the original macOS setup" argument
   does not survive contact with the facts: there is no POSIX build tooling here
   to be compatible with. Real costs: the repo sits on `C:\` under OneDrive, so
   reaching it at `/mnt/c/Users/akull/OneDrive/Desktop/riscv_processor` crosses
   the 9p filesystem bridge and is slow; cloning into the WSL filesystem fixes
   the speed but leaves you maintaining two copies; and GTKWave needs WSLg.

3. **Vivado** — required only if the FPGA target is pursued. Read Known Issues
   #6, #7, #8 first; the design will not usefully synthesize as written.

Line endings: `core.autocrlf=true` is set on this checkout. The new
`.gitattributes` normalizes to LF going forward. Existing files were
deliberately **not** renormalized, so the working tree still holds whatever it
held before.

`core.filemode` was set to `false` on this repo during the audit. Seven files
were showing as modified purely because the executable bit could not be
preserved on the NTFS/OneDrive checkout — a macOS-to-Windows porting artifact
with zero content change. Git identity (`user.name`/`user.email`) was also set
**repo-locally** to match prior commits; this machine had none configured
globally.

**OneDrive:** this repo lives inside a synced OneDrive folder. Sync can race
with simulator output and git index writes. Worth moving to a local path.

---

## Known Issues

Ordered by severity. Tags: **[correctness bug]**, **[FPGA synthesis risk]**,
**[repo hygiene]**.

1. **[correctness bug] A RAW dependency at distance 3 reads a stale register.**
   `register_file.v:15–16` read the array combinationally; `register_file.v:24–26`
   write on `posedge clk`. There is no write-first transparency and no internal
   bypass. Forwarding (`riscv_top.v:222–235`) covers only distance 1 (EX/MEM) and
   distance 2 (MEM/WB). At distance 3 the producer has already left MEM/WB when
   the consumer reaches EX, and the consumer's ID-stage read happened one cycle
   *before* the write landed. Concretely: `ADDI x1,x0,5` followed by three
   instructions, the fourth reading `x1`, gets the old `x1`. The classic 5-stage
   design closes this with a write-in-first-half / read-in-second-half register
   file; this one does not. The README's claim of "hardware to correctly handle
   all data and control hazards" is false. Fix is either a negedge write, or a
   bypass mux in `reg_file` when
   `rg_write_en && rg_des_addr == rg_srN_addr && rg_des_addr != 0`.

   **Reproduced on this machine.** Program: `ADDI x1,x0,5` / `NOP` / `NOP` /
   `ADD x5,x1,x0` (distance 3) / `ADD x6,x1,x0` (distance 4, control). Result:

   ```
   x1 = 5   producer wrote correctly
   x5 = 0   <-- distance-3 consumer read a STALE x1
   x6 = 5   distance-4 consumer read the correct value
   ```

   Wrong answer, no warning, no X. Note the repo's own `test/top_tb.v` cannot
   catch this: it only ever builds distance-1 and distance-2 dependencies.

2. **[correctness bug] Every I-type ALU instruction executes as `ADDI`.**
   `control_unit.v:26–30` matches opcode `0010011` and hardcodes
   `alu_op = 2'b00` ("force add"), never inspecting `funct3`. `ANDI`, `ORI`,
   `XORI`, `SLTI`, `SLTIU`, `SLLI`, `SRLI`, `SRAI` therefore all perform an
   addition. No error, no trap — wrong results, silently.

   **Reproduced on this machine.** With `x1 = 5`, the instruction
   `ANDI x7, x1, 3` (`0x0030F393`) yielded `x7 = 8`. Correct `ANDI` is
   `5 & 3 = 1`; `8` is `5 + 3`, i.e. an `ADDI`.

3. **[correctness bug] Every conditional branch executes as `BEQ`.**
   `control_unit.v:48–56` keys on opcode `1100011` alone and always sets
   `alu_op = 2'b01` (subtract); `riscv_top.v:86` then tests only `ex_zero`.
   `funct3` is piped to EX (`riscv_top.v:189`) and ignored. `BNE` is therefore
   **inverted** — it branches exactly when it must not. `BLT`, `BGE`, `BLTU`,
   `BGEU` are equally wrong, and the ALU has no comparison operation to build
   them from anyway.

   **Reproduced on this machine.** Program: `ADDI x1,x0,5` / `ADDI x2,x0,7` /
   `BNE x1,x2,+8` (`0x00209463`) / `ADDI x3,x0,99` / `ADDI x4,x0,42`. Since
   `5 != 7` the branch must be taken and `x3` must stay 0. Result: **`x3 = 99`** —
   the branch was not taken. `BNE` behaves as `BEQ`, confirming the inversion.

4. **[correctness bug] All load and store widths execute as word.**
   `control_unit.v:31–47` ignores `funct3` for both opcodes, and `data_mem` is
   word-only (`data_mem.v:14` and `:18`, both indexing `memory[addr[11:2]]`).
   There is no byte enable, no `funct3` port on the memory, and no
   sign/zero-extension on the load path — `id_ex_funct3` is dropped after EX and
   never reaches MEM or WB. `LB`, `LH`, `LBU`, `LHU`, `SB`, `SH` all move a full
   word, unaware of alignment. The LB/LH-versus-LBU/LHU distinction does not
   exist to be gotten wrong.

5. **[correctness bug] Unimplemented opcodes decode to a silent NOP.**
   `control_unit.v:59–61` is an empty `default`, so unknown opcodes inherit the
   all-zero defaults from `control_unit.v:13–19` — `reg_write = 0`, no trap, no
   flag. `LUI`, `AUIPC`, `JAL`, `JALR`, `FENCE`, `ECALL`, `EBREAK` and the R-type
   `SLT/SLTU/XOR/SLL/SRL/SRA` all vanish. A program using them produces wrong
   answers rather than an obvious failure. For a teaching core, an
   `illegal_instruction` output would be worth more than the silence.

6. **[FPGA synthesis risk] Instruction memory is combinational-read; will not
   infer BRAM.** `instruction_mem.v:12` is a continuous assign, and the module
   has no clock port at all (`instruction_mem.v:1–4`). Vivado cannot map a
   combinational read into a Block RAM — it will build 1024x32 of distributed
   LUT ROM plus a large output mux. Wasteful on an XC7A35T and a likely critical
   path. BRAM inference needs the read registered.

7. **[FPGA synthesis risk] Data memory read is both combinational and gated;
   will not infer BRAM.** `data_mem.v:18` —
   `assign read_data = (mem_read) ? memory[addr[11:2]] : 32'b0`. Two separate
   blockers: the read is unclocked, and the `mem_read` mux on the memory output
   defeats the inference pattern outright. Result is 32 Kbit of distributed
   LUTRAM, consuming a large fraction of the SLICEM resources on a 35T. Note the
   write side (`data_mem.v:12–16`) *is* synchronous, so this is a mixed-style
   memory — the worst case for inference.

8. **[FPGA synthesis risk] The design cannot be put on a board as it stands.**
   `riscv_top` has no ports except `clk` and `rst` (`riscv_top.v:1–4`) — no
   outputs whatsoever. Synthesis will find nothing observable and optimize the
   entire pipeline away to nothing. There is also no `.xdc` in the repo, so no
   pin or clock constraints exist. Reaching a Basys 3 needs, at minimum: some
   output port (LEDs, seven-segment, UART), a constraints file, and a clocking
   plan. None of this is started.

9. **[FPGA synthesis risk] `$readmemh` with a bare relative path.**
   `instruction_mem.v:9` — `$readmemh("sample_program.hex", memory)`. In
   simulation this silently depends on the working directory; run `vvp` from
   anywhere but the repo root and instruction memory fills with X and the
   processor executes garbage with no diagnostic. For Vivado synthesis the file
   must be added to the project and the path made resolvable at elaboration.

10. **[correctness bug] Instruction fetch has no bounds check and runs off the
    end of the program.** `instruction_mem.v:12` indexes `memory[addr >> 2]` into
    a `[0:1023]` array with no range guard, and only 5 words are ever
    initialized. Past `0x10` the core fetches X forever. It happens to be
    harmless today — `control_unit`'s pre-assigned defaults keep `reg_write` at
    0 — but it is harmless by luck, not design, and it means the core has no
    defined halt condition. The testbench relies on `$finish` after a fixed
    `#200` (`test/top_tb.v:24`).

11. **[correctness bug, latent] Load-use detection ignores whether the ID-stage
    instruction actually reads `rs2`.** `riscv_top.v:94–96` compares `id_ex_rd`
    against both `id_rs1` and `id_rs2` unconditionally. For `ADDI` and `LW`,
    instruction bits `[24:20]` are immediate bits, not a register specifier — if
    they happen to match the destination of a load in EX, the pipeline stalls for
    no reason. This costs a cycle and never produces a wrong answer, so it is a
    performance wart rather than a live bug, but the condition is stated
    incorrectly and should be qualified by the ID instruction's format.

12. **[repo hygiene] Dead pipeline registers left over from a
    later-branch-resolution design.** `ex_mem_branch_target` (`riscv_top.v:261`),
    `ex_mem_zero` (`:263`), `ex_mem_branch` (`:270`), `ex_mem_pc_plus4` (`:260`)
    and `id_ex_pc_plus4` (`:182`) are all latched and **never read**. Branch
    resolution moved to EX (`riscv_top.v:86`) and these were not removed.
    `id_ex_funct7` is read only for bit 5 (`riscv_top.v:208`). Synthesis trims
    them; a human reading the file is misled into thinking there is a MEM-stage
    branch path.

13. **[repo hygiene] The one integration test passes, and that is misleading.**
    `test/top_tb.v` runs green (`PASS`, exit 0) on Icarus Verilog 12.0. It is the
    *only* self-checking test in the repo, it asserts on four registers, and it
    exercises exactly one code path: a taken `BEQ` with distance-1 and distance-2
    forwarding. It cannot fail on Known Issues #1, #2, #3, #4, or #5 — all of
    which are live, silent, wrong-answer bugs, and three of which were reproduced
    on this machine in a few lines of hex. A green suite here means almost
    nothing. The unit testbenches
    (`test/{alu,pc,register_file,fetch_stage,logic_test}_tb.v`) mostly `$display`
    and dump waveforms rather than assert, so they do not close the gap. The
    highest-value next step for this repo is a directed hazard-and-ISA test
    program set, not more RTL.

14. **[repo hygiene] Compiled simulator binaries were committed, carrying a
    hardcoded macOS path.** `riscv_sim` and `sim/*_sim` were tracked in git. Each
    is a vvp image beginning `#!/opt/local/bin/vvp` — a MacPorts location that
    does not exist on Windows or on most Linux installs. Even with a toolchain
    present these would not run. Moved to `_attic/`, not deleted, since they fall
    outside the delete whitelist. They are pure build output; delete them.

15. **[repo hygiene] No build automation of any kind.** No Makefile, no script,
    no TCL. The build exists only as three lines of prose in the README, with two
    unstated preconditions (must run from repo root; must not glob `test/*.v`).
    A five-line Makefile would remove both footguns.

16. **[repo hygiene] The README overstates what the hardware does.** It claims
    "hardware to correctly handle all data and control hazards" and a "Forwarding
    unit ... eliminating most stalls." Known Issues #1 contradicts the first
    claim outright. The README's instruction list is accurate; the hazard claim
    is not.

17. **[repo hygiene, latent] Stall outranks branch redirect in the PC mux.**
    `riscv_top.v:99` — `pc_in_mux = stall ? pc_out : pc_next`. If `stall` and
    `branch_taken` were ever simultaneously true, the branch target computed at
    `riscv_top.v:91` would be discarded and the branch lost. Currently
    unreachable, since `stall` requires `id_ex_mem_read` and `branch_taken`
    requires `id_ex_branch` and no instruction sets both. It becomes live the
    moment a load-with-branch or a second branch resolution path is added.

18. **[repo hygiene] Naming inconsistencies that cost a reader time.**
    `src/register_file.v` declares `module reg_file`. `test/top_tb.v` declares
    `module riscv_top_tb`, while a separate 0-byte `test/riscv_top_tb.v` also
    existed (now in `_attic/`). The repo is described as SystemVerilog but is
    Verilog-2001 throughout.

19. **[repo hygiene] The repo lives inside a synced OneDrive folder.** Sync can
    interleave with simulator output and git index writes. Move it to a local
    path.
