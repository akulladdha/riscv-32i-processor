# Errors Fixed

Running log of every defect fixed on the `fix-and-cover` branch, in the order it
was fixed. Each entry records the failing evidence *before* the change, the
change itself, and the evidence after.

Baseline for this work is tag `pre-fix` (= tag `pre-cleanup` plus the audit
docs). Issue numbers refer to the Known Issues list in `CLAUDE.md`.

Reproduce any test with:

```bash
bash tests/run_tests.sh <name>     # single test
bash tests/run_tests.sh            # everything
```

---

## Fix 0 — Distance-3 RAW hazard read a stale register

**Known Issue #1 · correctness bug · `src/register_file.v`**

### What was wrong

The register file read combinationally from the array while writing on
`posedge clk`, with no write-first transparency and no internal bypass. The
forwarding unit covers only distance 1 (EX/MEM → EX) and distance 2
(MEM/WB → EX). At distance 3 the producer has already left MEM/WB by the time
the consumer reaches EX, *and* the consumer's ID-stage read happened one cycle
before the write landed. The value fell through both nets.

This is the bug the classic 5-stage design closes by writing in the first half
of the cycle and reading in the second. This core did neither.

It was fixed first because every later test would otherwise have had to be
written around it.

### Failing evidence

`tests/progs/raw3.s` — producer, two NOPs, then consumers at distance 3 and 4:

```asm
    addi x1, x0, 5
    nop
    nop
    add  x5, x1, x0     # distance 3
    add  x6, x1, x0     # distance 4 - control
```

```
TEST raw3: FAIL
  ok   x1 producer = 5
  FAIL x5 distance-3: expected 5, got 0      <-- stale read
  ok   x6 distance-4 = 5
```

Note the repo's own `test/top_tb.v` passes both before and after this fix — it
only ever builds distance-1 and distance-2 dependencies, so it could never have
caught this.

### The change

11 lines added, 2 removed, confined to `src/register_file.v`. Both read ports
gain a bypass: if a write is active this cycle to the register being read,
return the write data instead of the array contents.

```verilog
wire wr_active = rg_write_en && (rg_des_addr != 5'b0);

assign rg_sr1_data = (rg_sr1_addr == 5'b0) ? 32'b0 :
                     (wr_active && (rg_des_addr == rg_sr1_addr)) ? rg_des_data :
                     registers[rg_sr1_addr];
```

`rg_sr2_data` is identical. The `rg_sr1_addr == 5'b0` test stays first, so `x0`
still reads as zero even while something writes; `wr_active` excludes
`rg_des_addr == 0`, so a write to `x0` is discarded on the bypass path exactly
as it is on the array path.

### Passing evidence

```
TEST raw3: PASS
TEST top_tb (original): PASS
passed: 2   failed: 0
```

---

## Fix 1 — R-type SLL SLT SLTU XOR SRL SRA all executed as ADD

**Known Issue #2 (R-type half) · correctness bug · `src/alu.v`, `src/riscv_top.v`**

### What was wrong

Two gaps stacked. The ALU implemented only four operations; the other six sat
commented out (`alu.v:17-22`). And the ALU-control decoder handled only
`funct3` 000/111/110, sending everything else to its `default` of ADD
(`riscv_top.v:211`). So six R-type instructions silently performed additions.

The commented-out draft was also wrong where it existed: its "set less than"
used `(a < b)`, an unsigned compare on `[31:0]` operands — `SLTU` semantics
under an `SLT` label.

### Failing evidence

Every result was an addition, which is what makes this dangerous — plausible
numbers, no X, no crash:

```
FAIL XOR  x3: expected 6,          got 22          (12 + 10)
FAIL SLL  x4: expected 48,         got 14          (12 + 2)
FAIL SRA  x10: expected 0xFFFFFFFC, got 0xFFFFFFF2 (-16 + 2)
FAIL SLT  x12: expected 1,         got 0xFFFFFFFC  (-16 + 12)
FAIL SLL  x17 shamt-mask: expected 24, got 45      (12 + 33)
... 10 failures total
```

### The change

11 lines. Six ALU cases, five decoder cases.

`SRA` uses `$signed(a) >>> b[4:0]`, `SLT` uses `$signed(a) < $signed(b)`, and
`SLTU` uses a plain unsigned compare — the signed/unsigned distinction the old
draft got wrong. All shifts mask the shift amount to `b[4:0]`, tested explicitly
by shifting with 33 and expecting a shift of 1.

### Passing evidence

```
TEST raw3: PASS
TEST rtype: PASS
TEST top_tb (original): PASS
passed: 3   failed: 0
```

---

## Fix 2 — Every I-type ALU instruction executed as ADDI

**Known Issue #2 · correctness bug · `src/control_unit.v`, `src/riscv_top.v`**

### What was wrong

`control_unit.v:26-30` matched opcode `0010011` and hardcoded `alu_op = 2'b00`
with the comment "force add", never inspecting `funct3`. All nine I-type ALU
instructions performed an addition.

### Failing evidence

```
FAIL XORI  x3:  expected 6,          got 22          (12 + 10)
FAIL ANDI  x5:  expected 8,          got 22
FAIL SLTI  x6:  expected 1,          got 0xFFFFFFF0  (-16 + 0)
FAIL SLLI  x10: expected 48,         got 14          (12 + 2)
FAIL SRAI  x12: expected 0xFFFFFFFC, got 1010        (-16 + 0x402)
... 10 failures
```

`ORI x4, x1, 3` **passed** while broken, because `12 | 3` and `12 + 3` are both
15. A weaker test would have scored that as working — a good reminder that
operand choice matters as much as coverage.

### The change

16 lines: one decoder line plus a `funct3` case. A new `alu_op = 2'b11` means
"I-type ALU", decoded like R-type except `funct3` 000 is always ADDI (there is
no SUBI) and `funct7[5]` matters only for `SRAI` vs `SRLI`. All eight `funct3`
values are listed, so the case needs no default and infers no latch.

Shift immediates need no special handling: `imm[4:0]` already lands in the low
bits of the sign-extended immediate, and the ALU masks to `b[4:0]`.

### Passing evidence

```
TEST itype: PASS      TEST raw3: PASS
TEST rtype: PASS      TEST top_tb (original): PASS
passed: 4   failed: 0
```
