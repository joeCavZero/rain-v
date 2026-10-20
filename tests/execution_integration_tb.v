`timescale 1ns/1ps
/* Front-end real (central_processing_unit) ligado ao execution_unit.
   O testbench faz o papel do backend que ainda nao existe: o register file
   e um array, o Issue emite todo slot valido e legal, e o redirect do
   execution_unit volta para o front-end.
   Programa em inputs/execution_program.hex. */
module execution_integration_tb;
reg clk = 0, reset = 1, stall = 0;
reg [2:0] issue_count = 0;
wire redirect;
wire [31:0] redirect_target;

wire [31:0] pc;
wire [127:0] decoded_instructions, decoded_pcs, decoded_immediate;
wire [3:0] decoded_valid, decoded_uses_rs1, decoded_uses_rs2, decoded_reg_write;
wire [3:0] decoded_mem_read, decoded_mem_write, decoded_alu_src_imm, decoded_illegal;
wire [19:0] decoded_rs1, decoded_rs2, decoded_rd, decoded_alu_op;
wire [7:0] decoded_wb_sel;
wire [15:0] decoded_branch_type;

central_processing_unit #(
    .IMEM_WORDS(16),
    .IMEM_FILE("inputs/execution_program.hex")
) front_end (.*);

reg [31:0] regs [0:31];
wire [127:0] rs1_values, rs2_values;
genvar g;
generate
    for (g = 0; g < 4; g = g + 1) begin : READ
        assign rs1_values[g*32 +: 32] = regs[decoded_rs1[g*5 +: 5]];
        assign rs2_values[g*32 +: 32] = regs[decoded_rs2[g*5 +: 5]];
    end
endgenerate

wire [3:0] issue_valid = decoded_valid & ~decoded_illegal;
wire [127:0] results, store_datas;
wire [3:0] lane_valid;
wire target_misaligned;

execution_unit execution (
    .issue_valid(issue_valid),
    .instruction_pcs(decoded_pcs),
    .immediates(decoded_immediate),
    .rs1_values(rs1_values),
    .rs2_values(rs2_values),
    .alu_ops(decoded_alu_op),
    .alu_src_imm(decoded_alu_src_imm),
    .uses_rs1(decoded_uses_rs1),
    .wb_sels(decoded_wb_sel),
    .branch_types(decoded_branch_type),
    .results(results),
    .store_datas(store_datas),
    .lane_valid(lane_valid),
    .redirect(redirect),
    .redirect_target(redirect_target),
    .target_misaligned(target_misaligned)
);

always #5 clk = ~clk;

// Espera ate o buffer conter o grupo que comeca em first_pc.
task wait_group;
    input [31:0] first_pc;
    integer guard;
    begin
        guard = 0;
        while (!(decoded_valid[0] === 1'b1 && decoded_pcs[31:0] === first_pc)) begin
            @(posedge clk); #1;
            guard = guard + 1;
            if (guard > 20) $fatal(1, "o grupo com pc=%h nao chegou", first_pc);
        end
    end
endtask

task expect_slot;
    input integer slot;
    input [31:0] expected_pc, expected_result;
    begin
        if (decoded_pcs[slot*32 +: 32] !== expected_pc)
            $fatal(1, "slot %0d: pc=%h, esperado %h", slot, decoded_pcs[slot*32 +: 32], expected_pc);
        if (results[slot*32 +: 32] !== expected_result)
            $fatal(1, "slot %0d (pc=%h): result=%h, esperado %h",
                   slot, expected_pc, results[slot*32 +: 32], expected_result);
    end
endtask

task expect_control;
    input [3:0]  expected_lane_valid;
    input        expected_redirect;
    input [31:0] expected_target;
    begin
        if (lane_valid !== expected_lane_valid || redirect !== expected_redirect ||
            (expected_redirect && redirect_target !== expected_target))
            $fatal(1, "pc=%h: lane_valid=%b redirect=%b target=%h, esperado lane_valid=%b redirect=%b target=%h",
                   decoded_pcs[31:0], lane_valid, redirect, redirect_target,
                   expected_lane_valid, expected_redirect, expected_target);
    end
endtask

integer k;

initial begin
    $dumpfile("target/wave.vcd"); $dumpvars(0, execution_integration_tb);

    for (k = 0; k < 32; k = k + 1) regs[k] = 32'hA5A50000 | k;
    regs[0] = 32'h00000000;
    regs[1] = 32'h00000005;
    regs[2] = 32'h00000007;
    regs[3] = 32'hFFFFFFFD;   // -3
    regs[5] = 32'h00001000;
    regs[6] = 32'h12345678;
    regs[8] = 32'hFFFFFFFF;

    @(negedge clk); reset = 0;

    // Grupo 0, retido no buffer (issue_count = 0) para conferir cada slot.
    wait_group(32'h00);
    if (decoded_valid !== 4'b1111) $fatal(1, "grupo 0 deveria ter 4 slots validos");
    expect_slot(0, 32'h00, 32'h0000000C);   // add 5+7
    expect_slot(1, 32'h04, 32'h00001004);   // auipc usa o PC do proprio slot
    expect_slot(2, 32'h08, 32'hABCDE000);   // lui
    expect_slot(3, 32'h0C, 32'h00001008);   // sw: endereco
    if (store_datas[127:96] !== 32'h12345678) $fatal(1, "sw: store_data incorreto");
    expect_control(4'b1111, 1'b0, 32'h0);

    // O backend passa a consumir o grupo inteiro a cada ciclo.
    @(negedge clk); issue_count = 4;

    // Grupo 1: beq tomado no slot 1 anula os slots 2 e 3.
    wait_group(32'h10);
    expect_slot(0, 32'h10, 32'h00000061);   // addi -3+100
    expect_control(4'b0011, 1'b1, 32'h00000034);
    // Slots anulados ainda calculam; conferir exercita alu_op != ADD
    // nas lanes 2 e 3.
    expect_slot(2, 32'h18, 32'hFFFFFFFE);   // sub 5-7
    expect_slot(3, 32'h1C, 32'hFFFFFFEB);   // mul -3*7

    // O redirect chega ao front-end: o proximo grupo comeca no alvo.
    // O ultimo slot passa do fim da ROM e vem invalido.
    wait_group(32'h34);
    if (decoded_valid !== 4'b0111) $fatal(1, "grupo em 0x34 deveria ter valid=0111");
    expect_slot(0, 32'h34, 32'h00000038);   // jal: PC+4
    expect_control(4'b0001, 1'b1, 32'h00000000);
    expect_slot(1, 32'h38, 32'hEDCBA987);   // xor anulado
    expect_slot(2, 32'h3C, 32'h00000007);   // or anulado
    if (target_misaligned !== 1'b0) $fatal(1, "alvo 0x0 esta alinhado");

    // O jal volta para 0x00 e o programa recomeca.
    wait_group(32'h00);
    expect_slot(0, 32'h00, 32'h0000000C);

    $display("PASS execution_integration");
    $finish;
end
endmodule
