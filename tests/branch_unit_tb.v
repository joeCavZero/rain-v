`timescale 1ns/1ps
module branch_unit_tb;
reg valid;
reg [3:0] branch_type;
reg [31:0] instruction_pc, immediate, rs1_value, rs2_value;
wire taken, redirect;
wire [31:0] target;
branch_unit dut(.*);

localparam NONE=4'd0, BEQ=4'd1, BNE=4'd2, BLT=4'd3, BGE=4'd4, BLTU=4'd5, BGEU=4'd6,
           JAL=4'd7, JALR=4'd8;

integer kind;

task check;
    input        v;
    input [3:0]  kind_in;
    input [31:0] a, b, pc, imm;
    input        expected_taken;
    input [31:0] expected_target;
    begin
        valid = v; branch_type = kind_in; rs1_value = a; rs2_value = b;
        instruction_pc = pc; immediate = imm; #1;
        if (taken !== expected_taken || target !== expected_target || redirect !== (v && expected_taken))
            $fatal(1, "tipo=%0d valid=%b rs1=%h rs2=%h pc=%h imm=%h: taken=%b target=%h redirect=%b, esperado taken=%b target=%h",
                   kind_in, v, a, b, pc, imm, taken, target, redirect, expected_taken, expected_target);
    end
endtask

// Desvio condicional com pc=0x100 e offset +8.
task cond;
    input [3:0]  kind_in;
    input [31:0] a, b;
    input        expected_taken;
    begin
        check(1, kind_in, a, b, 32'h100, 32'h8, expected_taken, 32'h108);
    end
endtask

initial begin
    $dumpfile("target/wave.vcd"); $dumpvars(0, branch_unit_tb);

    cond(BEQ, 32'd5, 32'd5, 1);
    cond(BEQ, 32'd5, 32'd6, 0);
    cond(BNE, 32'd5, 32'd6, 1);
    cond(BNE, 32'd5, 32'd5, 0);

    // (-1, 1) e (INT_MIN, INT_MAX) separam signed de unsigned.
    cond(BLT,  32'hFFFFFFFF, 32'd1,        1);
    cond(BLT,  32'd1,        32'hFFFFFFFF, 0);
    cond(BLT,  32'h80000000, 32'h7FFFFFFF, 1);
    cond(BLT,  32'd3,        32'd3,        0);
    cond(BGE,  32'hFFFFFFFF, 32'd1,        0);
    cond(BGE,  32'd1,        32'hFFFFFFFF, 1);
    cond(BGE,  32'h7FFFFFFF, 32'h80000000, 1);
    cond(BGE,  32'd3,        32'd3,        1);
    cond(BLTU, 32'hFFFFFFFF, 32'd1,        0);
    cond(BLTU, 32'd1,        32'hFFFFFFFF, 1);
    cond(BLTU, 32'h80000000, 32'h7FFFFFFF, 0);
    cond(BLTU, 32'd3,        32'd3,        0);
    cond(BGEU, 32'hFFFFFFFF, 32'd1,        1);
    cond(BGEU, 32'd1,        32'hFFFFFFFF, 0);
    cond(BGEU, 32'h80000000, 32'h7FFFFFFF, 1);
    cond(BGEU, 32'd3,        32'd3,        1);

    // Alvo = PC da instrucao + imediato, com offset negativo e wrap.
    check(1, BEQ, 32'd0, 32'd0, 32'h00000100, 32'hFFFFFFF0, 1, 32'h000000F0);
    check(1, BEQ, 32'd0, 32'd0, 32'hFFFFFFFC, 32'h00000008, 1, 32'h00000004);

    // JAL: sempre taken, alvo relativo ao PC; rs1/rs2 nao importam.
    check(1, JAL, 32'h12345678, 32'h9ABCDEF0, 32'h00000100, 32'hFFFFFF00, 1, 32'h00000000);
    check(1, JAL, 32'h12345678, 32'h9ABCDEF0, 32'hFFFFFFFC, 32'h00000008, 1, 32'h00000004);
    check(1, JAL, 32'd0,        32'd0,        32'h00000200, 32'h00000010, 1, 32'h00000210);

    // JALR: alvo = (rs1 + imm) com bit 0 zerado; o PC nao entra.
    check(1, JALR, 32'h00001001, 32'd0, 32'h00000500, 32'h00000000, 1, 32'h00001000);
    check(1, JALR, 32'h00001002, 32'd0, 32'h00000500, 32'h00000000, 1, 32'h00001002);
    check(1, JALR, 32'h00001000, 32'd0, 32'h00000500, 32'hFFFFFFFC, 1, 32'h00000FFC);
    check(1, JALR, 32'h00001003, 32'd0, 32'h00000500, 32'hFFFFFFFE, 1, 32'h00001000);
    check(1, JALR, 32'hFFFFFFFF, 32'd0, 32'h00000500, 32'h00000002, 1, 32'h00000000);

    // valid=0: taken continua refletindo a condicao, redirect nao.
    check(0, JAL,  32'd0, 32'd0, 32'h100, 32'h8, 1, 32'h108);
    check(0, BEQ, 32'd5, 32'd5, 32'h100, 32'h8, 1, 32'h108);

    // valid=0 com operandos desconhecidos nunca redireciona.
    valid = 0; branch_type = BEQ; rs1_value = 32'bx; rs2_value = 32'bx; #1;
    if (redirect !== 1'b0) $fatal(1, "redirect deve ser 0 com valid=0 e operandos X");

    // Tipo 0 e codigos sem desvio condicional: nunca taken.
    check(1, NONE, 32'd5, 32'd5, 32'h100, 32'h8, 0, 32'h108);
    for (kind = 9; kind < 16; kind = kind + 1)
        check(1, kind[3:0], 32'd5, 32'd5, 32'h100, 32'h8, 0, 32'h108);

    $display("PASS branch_unit");
    $finish;
end
endmodule
