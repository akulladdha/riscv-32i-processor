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
