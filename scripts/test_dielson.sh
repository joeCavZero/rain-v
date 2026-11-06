#!/bin/sh
set -eu
mkdir -p target
for name in dependency_checker hazard_detection_unit forwarding_unit issue_unit pipeline_control; do
    echo "=== ${name}_tb ==="
    iverilog -g2012 -Wall -s "${name}_tb" -o target/dielson_output src/*.v "tests/${name}_tb.v"
    vvp target/dielson_output
done
echo "=== dielson_backend_1stage_integration_tb ==="
iverilog -g2012 -Wall -s dielson_backend_1stage_integration_tb -o target/dielson_output src/*.v tests/dielson_backend_1stage_integration_tb.v
vvp target/dielson_output
