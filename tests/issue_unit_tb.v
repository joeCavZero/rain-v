`timescale 1ns/1ps
/* Issue Unit in-order: prefixo emitido ate o primeiro obstaculo, no-op
   ilegal descartado sem parar o prefixo, RAW do proprio grupo, dependencia
   pendente sem dado (retira tudo e stall), resolved pelo forwarding, buffer
   vazio sem stall.
*/
module issue_unit_tb;
reg [3:0] group_valid = 0;
reg [3:0] illegal = 0;
reg [3:0] raw_group = 0;
reg [3:0] rs1_resolved = 0, rs2_resolved = 0;
wire [3:0] issue_valid, consumed;
wire [2:0] issue_count;
wire stall_request;
issue_unit dut(.*);

task expect_cycle;
    input [3:0] eissue, econsumed;
    input [2:0] ecount;
    input       estall;
    input [255:0] msg;
    begin
        #1; // deixa as atribuicoes continuas do DUT assentarem antes de ler
        if (issue_valid !== eissue || consumed !== econsumed ||
            issue_count !== ecount || stall_request !== estall)
            $fatal(1, "%0s: issue=%b consumed=%b count=%0d stall=%b, esperado issue=%b consumed=%b count=%0d stall=%b",
                   msg, issue_valid, consumed, issue_count, stall_request,
                   eissue, econsumed, ecount, estall);
    end
endtask

task set_resolved_clear;
    rs1_resolved = 4'b1111; rs2_resolved = 4'b1111;
    raw_group = 4'b0; illegal = 4'b0;
endtask

initial begin
    $dumpfile("target/wave_issue_unit.vcd"); $dumpvars(0, issue_unit_tb);

    // Buffer vazio: nada emitido, sem stall.
    expect_cycle(0, 0, 0, 0, "buffer vazio sem stall");

    // Quatro independentes e resolvidas: emite tudo.
    group_valid = 4'b1111; set_resolved_clear;
    expect_cycle(4'b1111, 4'b1111, 3'd4, 1'b0, "quatro prontas: emite tudo");

    // RAW do proprio grupo na lane 1: emite so a lane 0 (sem stall).
    raw_group = 4'b0010;
    expect_cycle(4'b0001, 4'b0001, 3'd1, 1'b0, "RAW na lane 1");

    // RAW na lane 2 (lane 1 ok): prefixo para na lane 2.
    raw_group = 4'b0100;
    expect_cycle(4'b0011, 4'b0011, 3'd2, 1'b0, "RAW na lane 2");

    // Pendencia sem dado na lane 0: nada emite, stall pedido.
    raw_group = 0; rs1_resolved = 4'b1110; rs2_resolved = 4'b1110;
    expect_cycle(4'b0000, 4'b0000, 3'd0, 1'b1, "pendencia sem dado: stall");

    // Coberta pelo forwarding (resolved): emite tudo de novo.
    rs1_resolved = 4'b1111; rs2_resolved = 4'b1111;
    expect_cycle(4'b1111, 4'b1111, 3'd4, 1'b0, "resolvidas de novo");

    // Pendencia por rs2 na lane 3: prefixo de 3.
    rs2_resolved = 4'b0111;
    expect_cycle(4'b0111, 4'b0111, 3'd3, 1'b0, "lane 3 pendente");
    rs2_resolved = 4'b1111;

    // Lane 0 pendente no rs1: in-order nao pula a lane 0, nada emite (stall).
    rs1_resolved = 4'b1110;
    expect_cycle(4'b0000, 4'b0000, 3'd0, 1'b1, "lane 0 pendente: stall");
    rs1_resolved = 4'b1111;

    // Ilegal na lane 0: descartada como no-op (consome) e o resto emite.
    illegal = 4'b0001;
    expect_cycle(4'b1110, 4'b1111, 3'd4, 1'b0, "ilegal na lane 0");

    // Ilegal na lane 2: lanes 0,1 e 3 emitem, count inclui o no-op.
    illegal = 4'b0100;
    expect_cycle(4'b1011, 4'b1111, 3'd4, 1'b0, "ilegal na lane 2");

    // Ilegal junto de RAW na lane seguinte: prefixo para de qualquer forma.
    illegal = 4'b0010;
    raw_group = 4'b0100;
    expect_cycle(4'b0001, 4'b0011, 3'd2, 1'b0, "ilegal + RAW");
    illegal = 0; raw_group = 0;

    // Lanes 0 a 2 livres, lane 3 pendente no rs2: emite 3.
    rs2_resolved = 4'b0111;
    expect_cycle(4'b0111, 4'b0111, 3'd3, 1'b0, "lane 3 pendente de novo");

    // Grupo parcial (buffer com sobra): emite so as lanes existentes.
    rs2_resolved = 4'b1111; group_valid = 4'b0011;
    expect_cycle(4'b0011, 4'b0011, 3'd2, 1'b0, "grupo parcial");

    $display("PASS issue_unit");
    $finish;
end
endmodule
