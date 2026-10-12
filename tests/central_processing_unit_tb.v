`timescale 1ns/1ps
module central_processing_unit_tb;
reg clk=0,reset=1,stall=0,redirect=0;
reg [31:0] redirect_target=0;
reg [2:0] issue_count=0;
wire [31:0] pc;
wire [127:0] decoded_instructions,decoded_pcs,decoded_immediate;
wire [3:0] decoded_valid,decoded_uses_rs1,decoded_uses_rs2,decoded_reg_write,decoded_mem_read,decoded_mem_write,decoded_alu_src_imm,decoded_illegal;
wire [19:0] decoded_rs1,decoded_rs2,decoded_rd,decoded_alu_op;
wire [7:0] decoded_wb_sel;wire [15:0] decoded_branch_type;
central_processing_unit #(.IMEM_WORDS(16)) dut(.*);
always #5 clk=~clk;
initial begin
 $dumpfile("target/wave.vcd");$dumpvars(0,central_processing_unit_tb);
 dut.fetch_unit.rom[0]=32'h003100b3;
 dut.fetch_unit.rom[1]=32'hfff00093;
 @(negedge clk);reset=0;
 @(posedge clk);#1;
 if(pc!=16 || decoded_valid!=15 || decoded_instructions[31:0]!=32'h003100b3 || decoded_rd[4:0]!=1) $fatal(1,"fetch/decode");
 @(negedge clk);issue_count=2;
 @(posedge clk);#1;
 if(decoded_valid!=3 || decoded_pcs[31:0]!=8) $fatal(1,"issue parcial");
 @(negedge clk);issue_count=0;redirect=1;redirect_target=32'h20;
 @(posedge clk);#1;
 if(pc!=32'h20 || decoded_valid!=0) $fatal(1,"redirect/flush");
 @(negedge clk);redirect=0;
 @(posedge clk);#1;
 if(decoded_pcs[31:0]!=32'h20 || decoded_valid!=15) $fatal(1,"refetch");
 $display("PASS central_processing_unit (somente front-end)");$finish;
end
endmodule
