`timescale 1ns/1ps
module pipeline_registers_tb;
reg clk=0,reset=1,flush=0,stall=0,load=0;
reg [2:0] consume_count=0;
reg [127:0] instructions_in=0,pc_in=0;
reg [3:0] valid_in=4'b1111;
wire [127:0] instructions_out,pc_out;wire [3:0] valid_out;wire empty;
pipeline_registers dut(.*);
always #5 clk=~clk;
initial begin
 $dumpfile("target/wave.vcd");$dumpvars(0,pipeline_registers_tb);
 instructions_in={32'd4,32'd3,32'd2,32'd1};pc_in={32'd12,32'd8,32'd4,32'd0};
 @(negedge clk);reset=0;load=1;
 @(posedge clk);#1;if(valid_out!=15 || instructions_out[31:0]!=1) $fatal(1,"load");
 @(negedge clk);load=0;consume_count=2;
 @(posedge clk);#1;if(valid_out!=3 || instructions_out[31:0]!=3 || pc_out[31:0]!=8) $fatal(1,"shift");
 @(negedge clk);stall=1;
 @(posedge clk);#1;if(valid_out!=3) $fatal(1,"stall");
 @(negedge clk);flush=1;
 @(posedge clk);#1;if(!empty) $fatal(1,"flush");
 $display("PASS pipeline_registers");$finish;
end
endmodule
