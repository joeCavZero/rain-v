`timescale 1ns/1ps
module program_counter_tb;
reg clk=0,reset=1,enable=0,redirect=0;
reg [31:0] redirect_target=0;
reg [2:0] advance_words=4;
wire [31:0] value;
program_counter dut(.*);
always #5 clk=~clk;
initial begin
 $dumpfile("target/wave.vcd"); $dumpvars(0,program_counter_tb);
 @(negedge clk); reset=0;enable=1;
 @(posedge clk);#1;if(value!==16) $fatal(1,"PC deveria ser 16");
 @(negedge clk);enable=0;
 @(posedge clk);#1;if(value!==16) $fatal(1,"PC deve parar");
 @(negedge clk);redirect=1;redirect_target=32'h80;
 @(posedge clk);#1;if(value!==32'h80) $fatal(1,"redirect falhou");
 @(negedge clk);redirect=0;enable=1;advance_words=2;
 @(posedge clk);#1;if(value!==32'h88) $fatal(1,"avanco parcial falhou");
 $display("PASS program_counter");$finish;
end
endmodule
