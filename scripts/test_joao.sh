#!/bin/sh
set -eu
mkdir -p target
for name in program_counter immediate_generator instruction_decoder instruction_fetch pipeline_registers central_processing_unit; do
  echo "=== $name ==="
  iverilog -g2012 -s "${name}_tb" -o target/output src/*.v "tests/${name}_tb.v"
  vvp target/output
done
