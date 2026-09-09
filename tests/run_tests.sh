#!/usr/bin/env bash
# Assemble every tests/progs/*.s, build every tests/tb/*_tb.v, run them all,
# and report a tally. Also runs the original test/top_tb.v as a regression.
#
#   bash tests/run_tests.sh          # all tests
#   bash tests/run_tests.sh alu      # only tests whose name matches "alu"
#
# Must be run from the repo root ($readmemh paths are relative to CWD).

set -u
cd "$(dirname "$0")/.." || exit 1
FILTER="${1:-}"
BUILD="tests/build"
mkdir -p "$BUILD"

pass=0; fail=0; failed_names=""

# ---- assemble programs ----
for s in tests/progs/*.s; do
    [ -e "$s" ] || continue
    perl tests/asm.pl "$s" "${s%.s}.hex" >/dev/null || { echo "ASSEMBLE ERROR: $s"; exit 1; }
done

# ---- the repo's original integration test ----
run_original() {
    [ -n "$FILTER" ] && case "top_tb" in *"$FILTER"*) ;; *) return ;; esac
    iverilog -o "$BUILD/top_tb" src/*.v test/top_tb.v 2>"$BUILD/top_tb.log" || {
        echo "  COMPILE FAIL top_tb"; fail=$((fail+1)); failed_names="$failed_names top_tb"; return; }
    out=$(vvp "$BUILD/top_tb" 2>&1 | grep -v "Not enough words")
    if echo "$out" | grep -q "^PASS:"; then
        echo "TEST top_tb (original): PASS"; pass=$((pass+1))
    else
        echo "TEST top_tb (original): FAIL"; echo "$out" | sed 's/^/    /'
        fail=$((fail+1)); failed_names="$failed_names top_tb"
    fi
}

# ---- generated tests ----
for tb in tests/tb/*_tb.v; do
    [ -e "$tb" ] || continue
    name=$(basename "$tb" _tb.v)
    if [ -n "$FILTER" ]; then case "$name" in *"$FILTER"*) ;; *) continue ;; esac; fi
    if ! iverilog -I tests/tb -o "$BUILD/$name" src/*.v "$tb" 2>"$BUILD/$name.log"; then
        echo "TEST $name: COMPILE FAIL"; sed 's/^/    /' "$BUILD/$name.log"
        fail=$((fail+1)); failed_names="$failed_names $name"; continue
    fi
    out=$(vvp "$BUILD/$name" 2>&1 | grep -v "Not enough words")
    if echo "$out" | grep -q "PASS$"; then
        echo "TEST $name: PASS"; pass=$((pass+1))
    else
        echo "TEST $name: FAIL"; echo "$out" | grep -E "FAIL|ok " | sed 's/^/    /'
        fail=$((fail+1)); failed_names="$failed_names $name"
    fi
done

run_original

echo "----------------------------------------"
echo "passed: $pass   failed: $fail"
[ "$fail" -gt 0 ] && echo "failing:$failed_names"
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
