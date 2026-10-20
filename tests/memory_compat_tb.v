`timescale 1ns/1ps
module memory_compat_tb;
    reg clk=0;
    reg [31:0] address=0,write_data=0;
    reg write_enable=0;
    wire [31:0] read_data;
    memory dut (.*);
    always #5 clk=~clk;
    initial begin
        $dumpfile("target/wave.vcd");$dumpvars(0,memory_compat_tb);
        $readmemh("inputs/memory_input.txt",dut.mem);
        #1;
        if(read_data !== 32'h003100B3) $fatal(1,"legacy readmemh");
        @(negedge clk);address=32'd4;write_data=32'hcafef00d;write_enable=1;
        @(posedge clk);#1;
        if(read_data !== 32'hcafef00d) $fatal(1,"legacy write");
        @(negedge clk);address=32'h400;write_data=32'hdeadbeef;
        @(posedge clk);#1;
        if(read_data !== 0) $fatal(1,"range");
        @(negedge clk);address=32'd4;write_enable=0;
        #1; if(read_data !== 32'hcafef00d) $fatal(1,"legacy aliased data");
        $display("PASS memory_compat_tb");$finish;
    end
endmodule
