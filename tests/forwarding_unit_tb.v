`timescale 1ns/1ps
/* Bypass de operandos: prioridade da fonte mais recente (fonte 0), fallback
   do banco, x0 jamais encaminhado, resolved quando sem pendencia ou com
   dado disponivel, pendencia sem dado (resolved = 0).
*/
module forwarding_unit_tb;
reg [3:0] uses_rs1 = 0, uses_rs2 = 0;
reg [19:0] rs1 = 0, rs2 = 0;
reg [127:0] rs1_bank = 0, rs2_bank = 0;
reg [3:0] pending_rs1 = 0, pending_rs2 = 0;
reg [7:0] source_valid = 8'b0;
reg [39:0] source_rd = 40'b0;
reg [255:0] source_data = 0;
wire [127:0] rs1_values, rs2_values;
wire [3:0] rs1_forwarded, rs2_forwarded, rs1_resolved, rs2_resolved;
forwarding_unit #(.SOURCES(8)) dut(.*);

task set_lane;
    input integer lane;
    input        u1, u2;
    input [4:0]  a, b;
    input [31:0] bank1, bank2;
    begin
        uses_rs1[lane] = u1; uses_rs2[lane] = u2;
        rs1[lane*5 +: 5] = a; rs2[lane*5 +: 5] = b;
        rs1_bank[lane*32 +: 32] = bank1;
        rs2_bank[lane*32 +: 32] = bank2;
    end
endtask

task set_source;
    input integer p;
    input [4:0]  d;
    input [31:0] data;
    begin
        source_valid[p] = 1'b1;
        source_rd[p*5 +: 5] = d;
        source_data[p*32 +: 32] = data;
    end
endtask

task check_fwd;
    input [31:0] v1a, v1b, v1c, v1d;
    input [31:0] v2a, v2b, v2c, v2d;
    input [3:0]  f1, f2, r1, r2;
    input [255:0] msg;
    begin
        #1; // deixa o always @(*) do DUT reavaliar antes de ler
        if (rs1_values !== {v1d, v1c, v1b, v1a} || rs2_values !== {v2d, v2c, v2b, v2a} ||
            rs1_forwarded !== f1 || rs2_forwarded !== f2 ||
            rs1_resolved !== r1 || rs2_resolved !== r2)
            $fatal(1, "%0s: rs1=%h rs2=%h fwd=%b/%b res=%b/%b, esperado %h %h %b %b %b %b",
                   msg, rs1_values, rs2_values, rs1_forwarded, rs2_forwarded,
                   rs1_resolved, rs2_resolved,
                   {v1d, v1c, v1b, v1a}, {v2d, v2c, v2b, v2a}, f1, f2, r1, r2);
    end
endtask

initial begin
    $dumpfile("target/wave_forwarding_unit.vcd"); $dumpvars(0, forwarding_unit_tb);

    // Sem fontes e sem pendencias: passthrough do banco.
    set_lane(0, 1, 0, 5'd5, 5'd0, 32'h11111111, 32'h0);
    set_lane(1, 0, 1, 5'd0, 5'd6, 32'h22222222, 32'h33333333);
    set_lane(2, 1, 1, 5'd7, 5'd8, 32'h44444444, 32'h55555555);
    set_lane(3, 1, 0, 5'd9, 5'd0, 32'h66666666, 32'h0);
    check_fwd(32'h11111111, 32'h22222222, 32'h44444444, 32'h66666666,
            32'h0, 32'h33333333, 32'h55555555, 32'h0,
            4'b0000, 4'b0000, 4'b1111, 4'b1111, "passthrough do banco");

    // Fonte 0 (mais recente) escreve x5: lane 0 recebe por rs1.
    set_source(0, 5'd5, 32'hAAAAAAAA);
    check_fwd(32'hAAAAAAAA, 32'h22222222, 32'h44444444, 32'h66666666,
            32'h0, 32'h33333333, 32'h55555555, 32'h0,
            4'b0001, 4'b0000, 4'b1111, 4'b1111, "fonte 0 cobre rs1 da lane 0");

    // Duas fontes com o mesmo rd (fonte 2 mais antiga): fonte 0 vence.
    set_source(2, 5'd5, 32'hBBBBBBBB);
    check_fwd(32'hAAAAAAAA, 32'h22222222, 32'h44444444, 32'h66666666,
            32'h0, 32'h33333333, 32'h55555555, 32'h0,
            4'b0001, 4'b0000, 4'b1111, 4'b1111, "fonte mais recente vence");

    // rs2 chamando x8 via fonte 3 (rs_coberto na lane 2).
    set_source(3, 5'd8, 32'hCCCCCCCC);
    check_fwd(32'hAAAAAAAA, 32'h22222222, 32'h44444444, 32'h66666666,
            32'h0, 32'h33333333, 32'hCCCCCCCC, 32'h0,
            4'b0001, 4'b0100, 4'b1111, 4'b1111, "rs2 da lane 2 via fonte 3");

    // Pendencia SEM dado (load ainda em EX): resolved = 0 na lane 2.
    pending_rs1[2] = 1'b1;
    check_fwd(32'hAAAAAAAA, 32'h22222222, 32'h44444444, 32'h66666666,
            32'h0, 32'h33333333, 32'hCCCCCCCC, 32'h0,
            4'b0001, 4'b0100, 4'b1011, 4'b1111, "pendencia sem dado: resolved 0");

    // A pendencia da lane 0 ganha dado na fonte 6 (fontes 0 e 2 saem do ar):
    // resolved de volta a 1 e o valor vem da fonte 6.
    source_valid[0] = 1'b0;
    source_valid[2] = 1'b0;
    set_source(6, 5'd5, 32'hDDDDDDDD);
    check_fwd(32'hDDDDDDDD, 32'h22222222, 32'h44444444, 32'h66666666,
            32'h0, 32'h33333333, 32'hCCCCCCCC, 32'h0,
            4'b0001, 4'b0100, 4'b1011, 4'b1111, "fonte 6 cobre a pendencia");

    // x0 nunca e encaminhado: fonte rd x0 nao casa; leitura de x0 usa banco.
    set_source(7, 5'd0, 32'hEEEEEEEE);
    set_lane(0, 1, 0, 5'd0, 5'd0, 32'h11111111, 32'h0);
    check_fwd(32'h11111111, 32'h22222222, 32'h44444444, 32'h66666666,
            32'h0, 32'h33333333, 32'hCCCCCCCC, 32'h0,
            4'b0000, 4'b0100, 4'b1011, 4'b1111, "x0 nunca encaminhado");

    // Uses = 0: resolved incondicional, valor intocado.
    set_lane(3, 0, 0, 5'd9, 5'd0, 32'h66666666, 32'h0);
    check_fwd(32'h11111111, 32'h22222222, 32'h44444444, 32'h66666666,
            32'h0, 32'h33333333, 32'hCCCCCCCC, 32'h0,
            4'b0000, 4'b0100, 4'b1011, 4'b1111, "uses 0: resolved incondicional");

    $display("PASS forwarding_unit");
    $finish;
end
endmodule
