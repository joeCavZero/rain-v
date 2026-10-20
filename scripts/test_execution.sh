#!/bin/sh
# Testbenches das unidades de execucao.
# Uso: sh scripts/test_execution.sh
# Cada chamada de run recebe o nome do modulo e as fontes de que o
# testbench tests/<nome>_tb.v depende. So essas fontes sao compiladas.

set -eu

mkdir -p target

run() {
    name="$1"
    shift
    tb="tests/${name}_tb.v"
    top=$(sed -n 's/^[[:space:]]*module[[:space:]][[:space:]]*\([A-Za-z0-9_]*\).*/\1/p' "$tb" | head -n 1)
    log="target/${name}.log"

    echo "=== ${name} ==="
    iverilog -g2012 -Wall -Wno-timescale -s "$top" -o "target/${name}.out" "$@" "$tb"

    if ! vvp -n "target/${name}.out" > "$log" 2>&1; then
        cat "$log"
        echo "FALHA: ${name}"
        exit 1
    fi

    if ! grep -qx "PASS ${name}" "$log"; then
        cat "$log"
        echo "FALHA: ${name} nao imprimiu 'PASS ${name}'"
        exit 1
    fi

    echo "PASS ${name}"
}

run arithmetic_logic_unit src/arithmetic_logic_unit.v
run operand_selection src/operand_selection.v
