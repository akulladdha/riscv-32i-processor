# Coverage

State of the `fix-and-cover` branch. Measured, not estimated: every `Tested = Y`
below corresponds to an assertion in a self-checking testbench that fails when
the behaviour is wrong.

Scoring rules used here, applied strictly:

- An instruction that decodes but has no assertion is **Tested = N**.
- An instruction whose test only shows it doesn't crash is **Tested = N**.
- Where I was unsure whether something is genuinely exercised, it is marked
  **N** and said so.

Reproduce everything:

```bash
bash tests/run_tests.sh
```

Requires `iverilog` on PATH and must run from the repo root (`$readmemh` paths
are relative to the working directory). Current result: **15 passed, 0 failed.**

---

## Opcode matrix — RV32I base integer instruction set

| # | Instruction | Type | Implemented | Tested | Test file |
|---|---|---|---|---|---|
| 1 | `LUI` | U | Y | Y | `tests/progs/utype.s`, `x0.s` |
| 2 | `AUIPC` | U | Y | Y | `tests/progs/utype.s` |
| 3 | `JAL` | J | Y | Y | `tests/progs/jal.s`, `jalr.s` |
| 4 | `JALR` | I | Y | Y | `tests/progs/jalr.s` |
| 5 | `BEQ` | B | Y | Y | `tests/progs/bcond.s`, `flush.s`, `loaduse.s`, `test/top_tb.v` |
| 6 | `BNE` | B | Y | Y | `tests/progs/bcond.s` |
| 7 | `BLT` | B | Y | Y | `tests/progs/bcond.s` |
| 8 | `BGE` | B | Y | Y | `tests/progs/bcond.s` |
| 9 | `BLTU` | B | Y | Y | `tests/progs/bcond.s` |
| 10 | `BGEU` | B | Y | Y | `tests/progs/bcond.s` |
| 11 | `LB` | I | Y | Y | `tests/progs/loads.s` |
| 12 | `LH` | I | Y | Y | `tests/progs/loads.s` |
| 13 | `LW` | I | Y | Y | `tests/progs/loads.s`, `fwd.s`, `loaduse.s`, `stores.s` |
| 14 | `LBU` | I | Y | Y | `tests/progs/loads.s` |
| 15 | `LHU` | I | Y | Y | `tests/progs/loads.s` |
| 16 | `SB` | S | Y | Y | `tests/progs/stores.s` |
| 17 | `SH` | S | Y | Y | `tests/progs/stores.s` |
| 18 | `SW` | S | Y | Y | `tests/progs/stores.s`, `fwd.s`, `loaduse.s` |
| 19 | `ADDI` | I | Y | Y | `tests/progs/itype.s` and most others |
| 20 | `SLTI` | I | Y | Y | `tests/progs/itype.s` |
| 21 | `SLTIU` | I | Y | Y | `tests/progs/itype.s` |
| 22 | `XORI` | I | Y | Y | `tests/progs/itype.s` |
| 23 | `ORI` | I | Y | Y | `tests/progs/itype.s` |
| 24 | `ANDI` | I | Y | Y | `tests/progs/itype.s` |
| 25 | `SLLI` | I | Y | Y | `tests/progs/itype.s` |
| 26 | `SRLI` | I | Y | Y | `tests/progs/itype.s` |
| 27 | `SRAI` | I | Y | Y | `tests/progs/itype.s` |
| 28 | `ADD` | R | Y | Y | `tests/progs/fwd.s`, `raw3.s`, `x0.s` |
| 29 | `SUB` | R | Y | Y | `tests/progs/rtype.s` |
| 30 | `SLL` | R | Y | Y | `tests/progs/rtype.s` |
| 31 | `SLT` | R | Y | Y | `tests/progs/rtype.s` |
| 32 | `SLTU` | R | Y | Y | `tests/progs/rtype.s` |
| 33 | `XOR` | R | Y | Y | `tests/progs/rtype.s` |
| 34 | `SRL` | R | Y | Y | `tests/progs/rtype.s` |
| 35 | `SRA` | R | Y | Y | `tests/progs/rtype.s` |
| 36 | `OR` | R | Y | Y | `tests/progs/rtype.s` |
| 37 | `AND` | R | Y | Y | `tests/progs/rtype.s` |
| 38 | `FENCE` | — | Y (as NOP) | Y | `tests/progs/fence.s` |
| 39 | `ECALL` | — | **N** | N | — |
| 40 | `EBREAK` | — | **N** | N | — |

**Implemented: 38 / 40 = 95.0%**
**Tested: 38 / 40 = 95.0%** (38 / 38 = 100% of what is implemented)

Baseline before this work was 8 / 40 = 20% implemented, with no instruction
covered by an assertion outside `test/top_tb.v`'s four registers.

### Two entries that deserve scrutiny

**`FENCE` marked Implemented and Tested.** It is not separately decoded — it
falls through `control_unit`'s `default` to an all-zero control word. On a
single-hart, in-order core with no caches and no store buffer, retiring `FENCE`
as a no-op is a *complete and correct* implementation of its architectural
requirement, so I scored it Y. The test asserts it writes no register and
leaves the surrounding pipeline intact, which is the whole of its observable
semantics here. If you disagree with that reading, downgrade both columns to N
and the totals become 37/40 = 92.5%.

**`ADD` tested only incidentally.** No test targets `ADD` as its subject; it is
covered because `fwd.s`, `raw3.s`, and `x0.s` all depend on it producing correct
sums, and they fail if it does not. That is a genuine assertion, so Y — but it
is weaker coverage than the dedicated cases.

---

## Hazard matrix

| Scenario | Tested | Test file |
|---|---|---|
| EX/MEM → EX forwarding (dependent ALU ops back to back) | Y | `tests/progs/fwd.s` |
| MEM/WB → EX forwarding (dependent ops one apart) | Y | `tests/progs/fwd.s` |
| Both forwarding sources contending for the same operand in one cycle | Y | `tests/progs/fwd.s` |
| Store-data forwarding into MEM | Y | `tests/progs/fwd.s` |
| Load-use stall (load followed immediately by a dependent instruction) | Y | `tests/progs/loaduse.s` |
| Load-use where the dependent instruction is a branch | Y | `tests/progs/loaduse.s` |
| Branch taken, flush killing the correct number of instructions | Y | `tests/progs/flush.s` |
| Branch not taken | Y | `tests/progs/bcond.s` |
| `JAL` flush behaviour | Y | `tests/progs/jal.s` |
| `JALR` flush behaviour | Y | `tests/progs/jalr.s` |
| Write to `x0` (must be discarded) | Y | `tests/progs/x0.s` |
| Same-cycle register file write and read of the same address | Y | `tests/progs/raw3.s` |
| Back-to-back branches | Y | `tests/progs/flush.s` |

**13 / 13 scenarios covered.**

### These were mutation-tested

Hazard tests that pass on first run prove nothing until you check they can
fail. Four deliberate RTL breakages, each confirming the right assertion —
and only that one — went red:

| Mutation | Caught by |
|---|---|
| Reverse forwarding priority (MEM/WB checked before EX/MEM) | `fwd`: contention `x7` = 5, not 9 |
| Force `stall = 0` | `loaduse`: `x4` = 65, and the branch consumer mispredicts |
| Flush ID/EX only, leaving IF/ID alive (depth 1) | `flush`: `x3` and `x14` survive |
| Allow writes to `x0` | `x0`: `registers[0]` = 14 |

One result worth keeping: under the `x0` mutation, every check that read `x0`
into another register **still passed**, because the register file hardwires
`x0` on the read port independently of the write path. Only inspecting
`registers[0]` directly catches a broken write-discard.

---

## Not implemented

### Tier 3 — structural, deliberately out of scope

| Item | What it would cost |
|---|---|
| `ECALL`, `EBREAK` | Trap machinery: `mtvec`/`mepc`/`mcause` CSRs, a privilege model, and a redirect path that preempts the pipeline ahead of branches and jumps. Larger than every fix on this branch combined. |
| Misaligned load/store traps | Depends on the same trap machinery. Addresses currently truncate silently — `data_mem` indexes `addr[11:2]` with no alignment check. |

### Known issues left standing

These are real and unfixed. They are not instruction coverage, so they did not
block this work, but they are not resolved either.

| Issue | Status |
|---|---|
| Neither memory is BRAM-inferrable (`CLAUDE.md` #6, #7) | Unfixed. Both reads are combinational; `data_mem`'s is also gated by `mem_read`. |
| `riscv_top` has no output ports, no `.xdc` (`CLAUDE.md` #8) | Unfixed. The design still cannot go on a board — synthesis would optimise it all away. |
| Instruction fetch has no bounds check (`CLAUDE.md` #10) | Unfixed. Past the program end the core fetches X forever; harmless only by luck. |
| Load-use stall ignores whether the ID instruction reads `rs2` (`CLAUDE.md` #11) | Unfixed. Causes spurious one-cycle stalls, never a wrong answer. |
| Dead EX/MEM branch registers (`CLAUDE.md` #12) | Unfixed, and now slightly worse: `alu_op = 2'b01` still drives a subtract for branches whose result the new comparator no longer uses. Removing it is a refactor, not a fix. |
| Stall outranks branch redirect in the PC mux (`CLAUDE.md` #17) | Unfixed and **still latent** — `stall` requires `id_ex_mem_read`, `redirect` requires `id_ex_branch` or `id_ex_jump`, and no instruction sets both. Adding a load-and-branch instruction would make it live. |

---

## Test inventory

| Test | Programs | What it asserts |
|---|---|---|
| `raw3` | `raw3.s` | Distance-3 RAW hazard; same-cycle regfile write/read |
| `rtype` | `rtype.s` | All ten R-type ALU ops, plus shift-amount masking |
| `itype` | `itype.s` | All nine I-type ALU ops, signed vs unsigned, arithmetic vs logical shift |
| `utype` | `utype.s` | `LUI`, `AUIPC`, and a `LUI`+`ADDI` pair |
| `bcond` | `bcond.s` | All six branch types, each in both directions |
| `loads` | `loads.s` | `LW` plus all four sub-word loads, sign- and zero-extension |
| `stores` | `stores.s` | `SB`/`SH` lane merging without clobbering neighbours |
| `jal` | `jal.s` | `JAL` link value and flush |
| `jalr` | `jalr.s` | `JALR` link, target, and the LSB clear |
| `fwd` | `fwd.s` | Four forwarding scenarios including source contention |
| `loaduse` | `loaduse.s` | Load-use interlock, ALU and branch consumers |
| `flush` | `flush.s` | Flush depth and back-to-back redirects |
| `x0` | `x0.s` | `x0` write discard from three different sources |
| `fence` | `fence.s` | `FENCE` as an architectural NOP |
| `top_tb` | `sample_program.hex` | The repo's original integration test, unmodified |

Tests are written in assembly and assembled by `tests/asm.pl`, a two-pass RV32I
assembler validated against encodings hand-checked against the spec. Hand-
encoding test programs was the alternative and is how encoding bugs get in.
