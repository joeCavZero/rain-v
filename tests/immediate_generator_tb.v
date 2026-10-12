`timescale 1ns/1ps
module immediate_generator_tb;
reg [31:0] instruction;wire [31:0] immediate;
immediate_generator dut(.*);
task check;input [31:0] inst, expected;begin instruction=inst;#1;
 if(immediate!==expected) $fatal(1,"imediato %h esperado %h obtido %h",inst,expected,immediate);
end endtask
initial begin
 $dumpfile("target/wave.vcd");$dumpvars(0,immediate_generator_tb);
 check(32'hfff00093,32'hffffffff); // addi x1,x0,-1
 check(32'h00112023,32'h0); // sw x1,0(x2)
 check(32'h00000463,32'h8); // beq x0,x0,+8
 check(32'h123450b7,32'h12345000); // lui
 check(32'h008000ef,32'h8); // jal +8
 $display("PASS immediate_generator");$finish;
end
endmodule
