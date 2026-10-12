`timescale 1ns/1ps
module instruction_fetch_tb;
reg [31:0] pc=0;wire [127:0] instructions;wire [3:0] valid;
instruction_fetch #(.WORDS(8)) dut(.*);
initial begin
 $dumpfile("target/wave.vcd");$dumpvars(0,instruction_fetch_tb);
 dut.rom[0]=32'h11111111;dut.rom[1]=32'h22222222;
 dut.rom[2]=32'h33333333;dut.rom[3]=32'h44444444;
 #1;if(valid!==4'b1111 || instructions[31:0]!==32'h11111111 || instructions[127:96]!==32'h44444444) $fatal(1,"fetch 4");
 pc=32'd24;#1;if(valid!==4'b0011) $fatal(1,"limite da ROM");
 pc=32'd1;#1;if(valid!==0) $fatal(1,"alinhamento");
 $display("PASS instruction_fetch");$finish;
end
endmodule
