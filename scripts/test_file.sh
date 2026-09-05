#!/bin/sh

set -e

NAME="$1"

if [ -z "$NAME" ]; then
    echo "Uso:"
    echo "  sh scripts/test_file.sh <nome>"
    echo
    echo "Exemplo:"
    echo "  sh scripts/test_file.sh program_counter"
    exit 1
fi

mkdir -p target

rm -f target/output
rm -f target/wave.vcd

iverilog \
    -g2012 \
    -o target/output \
    "src/${NAME}.v" \
    "tests/${NAME}_tb.v"

vvp target/output

if [ ! -f target/wave.vcd ]; then
    echo "Erro: a simulação não gerou target/wave.vcd"
    exit 1
fi

gtkwave target/wave.vcd