#!/bin/bash
# Compile and run the minimal test harness. Run from the repo root.
set -eo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT="$SCRIPT_DIR/.."

CXX="clang++"
CXXFLAGS="-std=c++17 -fobjc-arc -I$ROOT -I$ROOT/src/core -I$ROOT/src/macos -I$ROOT/metal-cpp -Wno-everything"

pass=0
fail=0

compile_and_run() {
    local src="$1"; shift
    local name
    name=$(basename "$src" | sed 's/\.[^.]*$//')
    local bin="/tmp/mq_${name}"
    # Some tests exercise the settings module and need to link it; others
    # (like test_addr) are self-contained. Probe by grepping for MQ_ refs
    # in the source so the build stays minimal per-test.
    local extra=""
    if grep -q "MQ_SaveSettings\|MQ_LoadSettings\|MQ_InitSettings\|MQ_GetSettings" "$src"; then
        extra="$ROOT/src/macos/Metal_Renderer_Main.cpp"
    fi
    $CXX $CXXFLAGS "$src" $extra -o "$bin" 2>&1 || {
        echo "COMPILE FAIL: $name"
        fail=$((fail + 1))
        return
    }
    if "$bin"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
    fi
    rm -f "$bin"
}

for t in "$SCRIPT_DIR"/test_*.cpp "$SCRIPT_DIR"/test_*.c; do
    [ -f "$t" ] || continue
    compile_and_run "$t"
done

echo ""
echo "Summary: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
