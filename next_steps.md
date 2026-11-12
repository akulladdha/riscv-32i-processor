# Next Steps — Getting This Onto a Basys 3

Written 2026-09-09, picking up from branch `fix-and-cover`. Self-contained: you
should not need any prior conversation to act on this.

---

## Where you left off

| | |
|---|---|
| Branch | `fix-and-cover` (off `repo-audit`, off `main`) |
| Undo points | tag `pre-cleanup` (before repo hygiene), tag `pre-fix` (before RTL fixes) |
| ISA | 38 / 40 RV32I implemented and tested (95%). Missing: `ECALL`, `EBREAK` |
| Tests | 15, all passing — `bash tests/run_tests.sh` from the repo root |
| Hazards | 13 / 13 scenarios covered, each mutation-tested |
| Toolchain | Icarus Verilog 12.0 at `C:\iverilog\bin`, GTKWave at `C:\iverilog\gtkwave\bin`, both on user PATH |

Read `COVERAGE.md` for the matrices and `errors_fixed.md` for what was fixed and
why. `CLAUDE.md` has the architecture audit and the remaining known issues.

**Nothing in this repo targets an FPGA yet.** No `.xdc`, no Vivado project, no
output ports. That is the work below.

---

## The one fact that blocks everything

`riscv_top` has exactly two ports — `clk` and `rst` ([riscv_top.v:1-6](src/riscv_top.v#L1-L6)).
No outputs.

Synthesis keeps only logic that can affect an output pin. So the *correct*
result of synthesizing this CPU today is an empty bitstream. Every step below is
downstream of giving the design an observable boundary.

This is not a quirk to work around. It is the first real lesson: synthesis is a
compiler doing aggressive dead-code elimination, and a passing testbench tells
it nothing.

---

## Phase 0 — Prove the toolchain before involving the CPU

Write a 26-bit counter driving one LED. Constraints file, synthesize, implement,
program the board. No processor involved.

**Why this comes first:** when the CPU eventually doesn't work, you want to
already know your pin constraints are right, your clock constraint is right, and
your programming flow works. Debugging four unknowns simultaneously is how
people abandon FPGA projects.

**Learning:** the whole Vivado flow — synthesis, implementation, place & route,
bitstream — and what each report is for.

**Pin names:** pull them from Digilent's official **Basys 3 Master XDC** rather
than from memory or from this file. The board's 100 MHz system clock is on pin
`W5`; confirm that and everything else against the master file. Downloading the
master XDC and uncommenting the lines you need is the standard workflow, not a
shortcut.

---

## Phase 1 — Synthesize the CPU and read the reports (do not program it yet)

Add output ports, run synthesis only, then read the utilization and timing
reports. Predictions to check against reality:

### Your memories will not be BRAM

- [instruction_mem.v:12](src/instruction_mem.v#L12) is a combinational `assign`
  with no clock at all. That cannot map to a Block RAM. Expect roughly 500 LUTs
  of distributed ROM plus a large mux tree.
- [data_mem.v:18](src/data_mem.v#L18) is worse:
  `assign read_data = (mem_read) ? memory[addr[11:2]] : 32'b0;`
  The ternary on the memory output defeats the inference pattern outright — even
  though the write side is properly clocked. A mixed-style memory is the worst
  case for inference.

### Your register file will be flip-flops, not LUTRAM

Subtle and worth understanding. A 32×32 file with 2 read ports and 1 write port
would normally infer as distributed RAM. But
[reg_file.v](src/reg_file.v) (the reset `for` loop) resets all 32 registers in a
`for` loop — and LUTRAM has no reset. That single loop forces ~1024 flip-flops.

Fine on an XC7A35T (~41k FFs), but note what happened: **your reset strategy
silently chose your memory primitive.**

### Learning from this phase

Memory inference is a *contract*. You write a specific pattern the tool
recognises; deviate and you get something else, with no error and no warning.
Read Xilinx **UG901**'s inference templates, then check the synthesis report for
what you actually got. This is the highest-value habit in FPGA work.

---

## Phase 2 — Synchronous memories, and the architecture change they force

The deepest part, and where most of the learning is.

### Data memory is nearly free

Make the read registered and unconditional. The BRAM's output register then
*becomes* your MEM/WB pipeline register for load data: address issued in MEM,
data valid at the start of WB. Load-use distance is unchanged, so the existing
stall logic still works.

**But there is a consequence you will hit immediately.** The sub-word load
extension currently sits in MEM, operating on `mem_read_data` *before* the
MEM/WB latch (added as Fix 5, see `errors_fixed.md`). With a synchronous BRAM
the raw word does not exist until WB, so the extension has to move to WB — which
means `funct3` needs a MEM/WB pipeline field, not just the EX/MEM one it has now.

### Instruction memory is the hard one

A registered read means the instruction arrives one cycle after you present the
PC. The clean approach is to let the BRAM's output register serve as
`if_id_instr` — but then flush and stall must control the *memory's* output
register (its enable and reset pins) rather than your own flops.

The usual escape hatch is a "kill" flag muxing a NOP in after the memory, which
costs you a mux on the critical path. Budget real time for this step.

### Learning from this phase

**Pipeline structure is downstream of memory technology.** Every textbook
5-stage diagram quietly assumes memory answers in zero time. The moment it
doesn't, you re-derive where data arrives, what can forward, and what must
stall. This is exactly why real CPUs look the way they do, and why a cache miss
is architecturally disruptive rather than merely slow.

---

## Phase 3 — Clocking, constraints, timing closure

You need `create_clock` in an `.xdc`. Without it **timing analysis does not run
at all**, and you get a bitstream that may work, may not, and may change
behaviour when you recompile.

You probably will not close 100 MHz on the first attempt. The likely critical
path is the branch resolve loop:

```
register file read -> forwarding mux -> funct3 comparator (EX) -> PC mux -> PC
```

That is a lot of combinational depth in one cycle. See
[riscv_top.v:88-106](src/riscv_top.v#L88-L106) for the comparator.

Two honest options: divide the clock to 25 or 50 MHz and move on, or
restructure. **Take the divider first** — knowing your actual Fmax is worth more
than hitting a round number.

**Learning:** timing is a constraint with a number attached, and slack is the
currency. Discovering from your own design that the branch path is the limiter
is a far better route to understanding why branch prediction and deeper
pipelines exist than reading about them.

---

## Phase 4 — Make it a computer: memory-mapped I/O

Carve an address range out of the data memory decode — say anything at or above
`0x8000` routes to peripherals instead of RAM. LEDs at one address, switches at
another, seven-segment at a third. Then write a program that reads switches and
lights LEDs.

**Learning:** memory-mapped I/O — that peripherals are just addresses — is one
of the genuinely load-bearing ideas in computer architecture. Building the
address decoder yourself makes it permanent.

**Also:** buttons and switches are asynchronous to your clock. Every one needs a
two-flop synchronizer, and buttons need debouncing. Simulation will never show
you a metastable flip-flop, which is exactly why this bites people on real
hardware.

---

## Phase 5 — On-board bring-up

Add an ILA (Integrated Logic Analyzer) core to watch the PC, the instruction,
and a couple of pipeline registers while it runs.

**Learning:** debugging without `$display`. You design observability in
deliberately, because you cannot add a print statement to a bitstream.

---

## Smaller items in the current code

| Item | Where | Note |
|---|---|---|
| ~~Wide array index~~ | `instruction_mem.v` | Fixed: now indexes `addr[11:2]`, like `data_mem`. |
| Program initialisation | [instruction_mem.v:9](src/instruction_mem.v#L9) | `$readmemh` *does* work for BRAM init in Vivado, but the `.hex` must be added to the project as a design source, not merely present in the directory. Your program becomes part of the bitstream. |
| No fetch bounds check | `CLAUDE.md` #10 | Past the program end the core fetches X forever. Harmless in simulation only by luck; on hardware it will execute whatever the BRAM initialises to. |
| Double ALU decode | `COVERAGE.md` | `id_ex_funct7` is piped 7 bits wide to be read for one bit. Folding decode into `control_unit` removes the field. |
| MEM/WB carries 65 bits | `COVERAGE.md` | Both candidate results plus a selector, where one resolved 32-bit result would do. |

The last two are optimisations, not blockers.

---

## Where the learning actually is, distilled

Four ideas, in rough order of how much they change how you think:

1. **Memory technology dictates pipeline structure.** Not the other way round.
2. **Synthesis is a contract you write to, not a translation of your intent.**
   Inference patterns, dead-code elimination, and the reset-vs-LUTRAM
   interaction are all the same lesson wearing different clothes.
3. **Timing is physical and quantified.** Your own critical path teaches you why
   architectural tricks exist.
4. **The outside world is asynchronous.** Synchronizers, debouncing, clock
   domain crossing.

---

## Recommended starting point

**Do Phase 0 and Phase 1 before anything else.**

Getting a bitstream on the board with a blinking LED, and separately reading a
synthesis report for the CPU as it stands, will teach you more in an afternoon
than a week of speculative RTL changes. The reports will tell you concretely
which of the predictions in Phase 1 are right for your design — treat them as
hypotheses to check, not facts.

**Scope warning:** Phases 2–4 together are comparable in effort to everything on
the `fix-and-cover` branch combined. If the goal is learning rather than a
finished product, Phase 1 plus a clock-divided Phase 2 is a defensible place to
stop.

---

## Housekeeping when you return

- Run `bash tests/run_tests.sh` first to confirm the 15 tests still pass before
  changing anything.
- Any RTL change for FPGA readiness should keep that suite green. The hazard
  tests are mutation-validated, so they will genuinely catch a regression in
  forwarding, stalling, or flush behaviour.
- `fix-and-cover` has not been merged to `main`. Decide whether to merge it
  before starting FPGA work, so the FPGA branch has a clean base.
