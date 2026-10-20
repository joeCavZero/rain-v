`timescale 1ns/1ps
module operand_selection_tb;
reg [31:0] rs1_value, rs2_value, instruction_pc, immediate;
reg alu_src_pc, alu_src_imm;
wire [31:0] rs1_fwd, rs2_fwd, operand_a, operand_b;
operand_selection dut(.*);

task check;
    input        pc_sel, imm_sel;
    input [31:0] expected_a, expected_b;
    begin
        alu_src_pc = pc_sel; alu_src_imm = imm_sel; #1;
        if (operand_a !== expected_a || operand_b !== expected_b)
            $fatal(1, "alu_src_pc=%0d alu_src_imm=%0d: A=%h B=%h, esperado A=%h B=%h",
                   pc_sel, imm_sel, operand_a, operand_b, expected_a, expected_b);
        if (rs1_fwd !== rs1_value || rs2_fwd !== rs2_value)
            $fatal(1, "rs1_fwd/rs2_fwd devem repetir as leituras do register file");
    end
endtask

initial begin
    $dumpfile("target/wave.vcd"); $dumpvars(0, operand_selection_tb);
    rs1_value = 32'h11111111; rs2_value = 32'h22222222;
    instruction_pc = 32'h00000040; immediate = 32'hFFFFF800;
    check(0, 0, 32'h11111111, 32'h22222222); // tipo R e branch
    check(0, 1, 32'h11111111, 32'hFFFFF800); // OP-IMM, load, store
    check(1, 1, 32'h00000040, 32'hFFFFF800); // AUIPC
    check(1, 0, 32'h00000040, 32'h22222222); // muxes independentes
    rs1_value = 32'hDEADBEEF; rs2_value = 32'h0BADF00D;
    check(0, 0, 32'hDEADBEEF, 32'h0BADF00D);
    $display("PASS operand_selection");
    $finish;
end
endmodule
