`timescale 1ns/1ps
module instruction_decoder_tb;
reg [31:0] instruction;
wire [4:0] rs1,rs2,rd,alu_op;
wire uses_rs1,uses_rs2,reg_write,mem_read,mem_write,alu_src_imm,illegal;
wire [1:0] wb_sel;wire [3:0] branch_type;wire [31:0] immediate;
instruction_decoder dut(.*);
initial begin
 $dumpfile("target/wave.vcd");$dumpvars(0,instruction_decoder_tb);
 instruction=32'h003100b3;#1; // add x1,x2,x3
 if(illegal || !reg_write || !uses_rs1 || !uses_rs2 || rs1!=2 || rs2!=3 || rd!=1 || alu_op!=0) $fatal(1,"ADD");
 instruction=32'hfff00093;#1; // addi x1,x0,-1
 if(illegal || !alu_src_imm || immediate!==32'hffffffff || uses_rs2) $fatal(1,"ADDI");
 instruction=32'h00012083;#1; // lw x1,0(x2)
 if(illegal || !mem_read || wb_sel!=1 || !reg_write) $fatal(1,"LW");
 instruction=32'h00112023;#1; // sw x1,0(x2)
 if(illegal || !mem_write || reg_write) $fatal(1,"SW");
 instruction=32'h00000463;#1; // beq x0,x0,+8
 if(illegal || branch_type!=1 || reg_write) $fatal(1,"BEQ");
 instruction=32'h008000ef;#1; // jal x1,+8
 if(illegal || branch_type!=7 || wb_sel!=2) $fatal(1,"JAL");
 instruction=32'hffffffff;#1;
 if(!illegal || reg_write || mem_write || mem_read) $fatal(1,"ilegal");
 $display("PASS instruction_decoder");$finish;
end
endmodule
