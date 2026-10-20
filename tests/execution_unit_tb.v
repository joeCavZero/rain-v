`timescale 1ns/1ps
/* Quatro lanes em paralelo: independencia entre lanes, prioridade do
   desvio mais velho e anulacao das lanes mais jovens. Os controles sao
   dirigidos direto, com os codigos do instruction_decoder. */
module execution_unit_tb;
reg [3:0] issue_valid;
reg [127:0] instruction_pcs, immediates, rs1_values, rs2_values;
reg [19:0] alu_ops;
reg [3:0] alu_src_imm, uses_rs1;
reg [7:0] wb_sels;
reg [15:0] branch_types;
wire [127:0] results, store_datas;
wire [3:0] lane_valid;
wire redirect, target_misaligned;
wire [31:0] redirect_target;
execution_unit dut(.*);

localparam ADD=5'd0, SUB=5'd1, XOR=5'd5, MUL=5'd10;
localparam BEQ=4'd1, BNE=4'd2, JALR=4'd8;

task set_lane;
    input integer lane;
    input [31:0] pc, imm, a, b;
    input [4:0]  op;
    input        imm_sel, reads_rs1;
    input [1:0]  wb;
    input [3:0]  branch;
    begin
        instruction_pcs[lane*32 +: 32] = pc;
        immediates[lane*32 +: 32] = imm;
        rs1_values[lane*32 +: 32] = a;
        rs2_values[lane*32 +: 32] = b;
        alu_ops[lane*5 +: 5] = op;
        alu_src_imm[lane] = imm_sel;
        uses_rs1[lane] = reads_rs1;
        wb_sels[lane*2 +: 2] = wb;
        branch_types[lane*4 +: 4] = branch;
    end
endtask

// Instrucao tipo R na lane, com PC = 0x100 + 4*lane.
task alu_lane;
    input integer lane;
    input [31:0] a, b;
    input [4:0]  op;
    begin
        set_lane(lane, 32'h100 + lane*4, 32'h0, a, b, op, 1'b0, 1'b1, 2'd0, 4'd0);
    end
endtask

// Desvio condicional na lane, alvo = PC + 0x40.
task branch_lane;
    input integer lane;
    input [31:0] a, b;
    input [3:0]  branch;
    begin
        set_lane(lane, 32'h100 + lane*4, 32'h40, a, b, ADD, 1'b0, 1'b1, 2'd0, branch);
    end
endtask

task expect_result;
    input integer lane;
    input [31:0] expected;
    begin
        if (results[lane*32 +: 32] !== expected)
            $fatal(1, "lane %0d: result=%h, esperado %h", lane, results[lane*32 +: 32], expected);
    end
endtask

task expect_control;
    input [3:0]  expected_lane_valid;
    input        expected_redirect;
    input [31:0] expected_target;
    begin
        #1;
        if (lane_valid !== expected_lane_valid || redirect !== expected_redirect ||
            (expected_redirect && redirect_target !== expected_target))
            $fatal(1, "lane_valid=%b redirect=%b target=%h, esperado lane_valid=%b redirect=%b target=%h",
                   lane_valid, redirect, redirect_target,
                   expected_lane_valid, expected_redirect, expected_target);
    end
endtask

reg [127:0] previous_results;

initial begin
    $dumpfile("target/wave.vcd"); $dumpvars(0, execution_unit_tb);

    // Quatro operacoes independentes no mesmo ciclo.
    issue_valid = 4'b1111;
    alu_lane(0, 32'd5, 32'd7, ADD);
    alu_lane(1, 32'd5, 32'd7, SUB);
    alu_lane(2, 32'h0000F0F0, 32'h00000FF0, XOR);
    alu_lane(3, 32'd3, 32'd4, MUL);
    expect_control(4'b1111, 0, 32'h0);
    expect_result(0, 32'h0000000C);
    expect_result(1, 32'hFFFFFFFE);
    expect_result(2, 32'h0000FF00);
    expect_result(3, 32'h0000000C);

    // Mudar uma lane nao altera as outras.
    previous_results = results;
    alu_lane(2, 32'h0000000F, 32'h000000F0, XOR); #1;
    expect_result(2, 32'h000000FF);
    if (results[31:0] !== previous_results[31:0] || results[63:32] !== previous_results[63:32] ||
        results[127:96] !== previous_results[127:96])
        $fatal(1, "alterar a lane 2 mudou outra lane");

    // ADDI le rs1; AUIPC (imediato sem rs1) soma o PC da instrucao.
    set_lane(0, 32'h100, 32'hFFFFFFFF, 32'd10, 32'd0, ADD, 1'b1, 1'b1, 2'd0, 4'd0);
    set_lane(1, 32'h104, 32'h00001000, 32'hDEAD0000, 32'd0, ADD, 1'b1, 1'b0, 2'd0, 4'd0);
    #1;
    expect_result(0, 32'h00000009);
    expect_result(1, 32'h00001104);

    // Store na lane: result = endereco, store_data = rs2.
    set_lane(2, 32'h108, 32'h00000010, 32'h00002000, 32'hCAFEBABE, ADD, 1'b1, 1'b1, 2'd0, 4'd0);
    #1;
    expect_result(2, 32'h00002010);
    if (store_datas[95:64] !== 32'hCAFEBABE) $fatal(1, "store_data da lane 2 incorreto");

    // Branch tomado na lane 1, add na lane 0 e stores nas lanes 2 e 3:
    // as lanes 2 e 3 sao anuladas, a lane 0 segue.
    alu_lane(0, 32'd1, 32'd2, ADD);
    branch_lane(1, 32'd5, 32'd5, BEQ);
    set_lane(2, 32'h108, 32'h0, 32'h00002000, 32'h11111111, ADD, 1'b1, 1'b1, 2'd0, 4'd0);
    set_lane(3, 32'h10C, 32'h4, 32'h00002000, 32'h22222222, ADD, 1'b1, 1'b1, 2'd0, 4'd0);
    expect_control(4'b0011, 1, 32'h00000144);

    // Dois desvios tomados (lanes 1 e 3): vence o mais velho.
    branch_lane(3, 32'd1, 32'd2, BNE);
    expect_control(4'b0011, 1, 32'h00000144);

    // Desvio nao tomado nao anula ninguem.
    alu_lane(1, 32'd1, 32'd1, ADD);
    alu_lane(3, 32'd1, 32'd1, ADD);
    branch_lane(0, 32'd5, 32'd6, BEQ);
    expect_control(4'b1111, 0, 32'h0);

    // Desvio tomado na lane 0 anula as outras tres.
    branch_lane(0, 32'd5, 32'd5, BEQ);
    expect_control(4'b0001, 1, 32'h00000140);

    // Desvio tomado na lane 3 nao tem lane mais jovem para anular.
    alu_lane(0, 32'd1, 32'd1, ADD);
    branch_lane(3, 32'd5, 32'd5, BEQ);
    expect_control(4'b1111, 1, 32'h0000014C);

    // Lane nao emitida nao redireciona nem anula.
    issue_valid = 4'b0111;
    expect_control(4'b0111, 0, 32'h0);
    issue_valid = 4'b1111;

    // JALR com alvo desalinhado: (0x1002 + 0) nao e multiplo de 4.
    set_lane(3, 32'h10C, 32'h0, 32'h00001002, 32'd0, ADD, 1'b0, 1'b1, 2'd2, JALR);
    expect_control(4'b1111, 1, 32'h00001002);
    if (target_misaligned !== 1'b1) $fatal(1, "alvo 0x1002 deveria ser desalinhado");
    set_lane(3, 32'h10C, 32'h0, 32'h00001004, 32'd0, ADD, 1'b0, 1'b1, 2'd2, JALR);
    expect_control(4'b1111, 1, 32'h00001004);
    if (target_misaligned !== 1'b0) $fatal(1, "alvo 0x1004 esta alinhado");
    expect_result(3, 32'h00000110);   // JALR escreve PC+4

    // Nada emitido e operandos desconhecidos: nenhum efeito.
    issue_valid = 4'b0000;
    rs1_values = {128{1'bx}}; rs2_values = {128{1'bx}};
    expect_control(4'b0000, 0, 32'h0);
    if (target_misaligned !== 1'b0) $fatal(1, "target_misaligned sem redirect");

    $display("PASS execution_unit");
    $finish;
end
endmodule
