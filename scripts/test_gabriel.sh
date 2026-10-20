#!/bin/sh
set -eu
mkdir -p target
for name in register_bank memory memory_compat memory_byte_enabled load_store_unit memory_arbiter memory_4wide memory_subsystem_4wide writeback_unit gabriel_integration; do
    case "$name" in
        memory) tb=memory_tb;;
        *) tb="${name}_tb";;
    esac
    echo "=== ${tb} ==="
    iverilog -g2012 -Wall -s "$tb" -o target/gabriel_output src/*.v "tests/${tb}.v"
    vvp target/gabriel_output
done
