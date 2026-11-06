`timescale 1ns/1ps
/* Dependencias RAW e WAW dentro do grupo de 4 instrucoes.
   Casos: exemplo do plano (add/sub/and/or), grupo independente, WAW,
   dependencia por rs2, escrita em x0, store que nao escreve rd, cadeia com
   WAW antes do leitor, slot invalido descartado da analise.
*/
module dependency_checker_tb;
reg [3:0] valid = 4'b1111;
reg [3:0] uses_rs1 = 0, uses_rs2 = 0, reg_write = 0;
reg [19:0] rs1 = 0, rs2 = 0, rd = 0;
wire [3:0] raw_dependency, waw_dependency;
dependency_checker dut(.*);

// Configura a lane: usa_rs1(+rs1), usa_rs2(+rs2), escreve(+rd)
task set_lane;
    input integer lane;
    input        u1, u2, wr;
    input [4:0]  a, b, d;
    begin
        uses_rs1[lane] = u1; uses_rs2[lane] = u2; reg_write[lane] = wr;
        rs1[lane*5 +: 5] = a; rs2[lane*5 +: 5] = b; rd[lane*5 +: 5] = d;
        valid[lane] = 1'b1;
    end
endtask

task check_masks;
    input [3:0] expected_raw, expected_waw;
    input [255:0] msg;
    begin
        #1; // deixa o always @(*) do DUT reavaliar antes de ler
        if (raw_dependency !== expected_raw || waw_dependency !== expected_waw)
            $fatal(1, "%0s: raw=%b waw=%b, esperado raw=%b waw=%b",
                   msg, raw_dependency, waw_dependency, expected_raw, expected_waw);
    end
endtask

initial begin
    $dumpfile("target/wave_dependency_checker.vcd"); $dumpvars(0, dependency_checker_tb);

    // Exemplo do plano: add x1/x2/x3, sub x4/x1, and, or.
    set_lane(0, 1, 1, 1, 5'd1, 5'd2, 5'd1);   // add x1, x2, x3
    set_lane(1, 1, 1, 1, 5'd4, 5'd1, 5'd4);   // sub x4, x1, x5 -> RAW com lane 0
    set_lane(2, 1, 1, 1, 5'd7, 5'd8, 5'd6);   // and x6, x7, x8
    set_lane(3, 1, 1, 1, 5'd10, 5'd11, 5'd9); // or  x9, x10, x11
    check_masks(4'b0010, 4'b0000, "exemplo do plano: RAW na lane 1");

    // Quatro independentes.
    set_lane(0, 1, 0, 1, 5'd20, 5'd0, 5'd1);
    set_lane(1, 1, 0, 1, 5'd21, 5'd0, 5'd2);
    set_lane(2, 1, 0, 1, 5'd22, 5'd0, 5'd3);
    set_lane(3, 1, 0, 1, 5'd23, 5'd0, 5'd4);
    check_masks(4'b0000, 4'b0000, "quatro independentes");

    // WAW nas lanes 1 e 2; RAW por rs2 na lane 2 e por rs1 na lane 3.
    set_lane(0, 1, 1, 1, 5'd5, 5'd6, 5'd7);   // escreve x7
    set_lane(1, 1, 1, 1, 5'd5, 5'd9, 5'd7);   // WAW com lane 0
    set_lane(2, 1, 1, 1, 5'd5, 5'd7, 5'd9);   // le x7 (rs2) e escreve x9
    set_lane(3, 1, 1, 1, 5'd9, 5'd2, 5'd8);   // le x9 (rs1, escrito na lane 2)
    check_masks(4'b1100, 4'b0010, "WAW lanes 1/2 + RAW rs2/rs1");

    // Escrita em x0 nao cria dependencia: lanes 2 e 3 dependem de lanes 1 e 2.
    set_lane(0, 0, 0, 1, 5'd0, 5'd0, 5'd0);   // addi x0, x0, 0
    set_lane(1, 1, 0, 1, 5'd0, 5'd0, 5'd12);  // le x0: sem dep com lane 0
    set_lane(2, 1, 0, 1, 5'd12, 5'd0, 5'd13); // RAW com lane 1
    set_lane(3, 1, 0, 1, 5'd13, 5'd0, 5'd14); // RAW com lane 2
    check_masks(4'b1100, 4'b0000, "escrita em x0 sem dependencia");

    // Store escreve apenas memoria (reg_write = 0): sem RAW de registrador.
    set_lane(0, 0, 1, 0, 5'd5, 5'd5, 5'd0);   // sw x5, 0(x5)
    set_lane(1, 1, 0, 1, 5'd5, 5'd0, 5'd15);  // le x5, mas a store nao escreve rd
    set_lane(2, 1, 0, 1, 5'd20, 5'd0, 5'd16); // independente
    set_lane(3, 1, 0, 1, 5'd21, 5'd0, 5'd17); // independente
    check_masks(4'b0000, 4'b0000, "store nao escreve rd");

    // Cadeia com WAW antes do leitor: lanes 0 e 1 escrevem x5, lane 3 le x5.
    set_lane(0, 1, 0, 1, 5'd2, 5'd0, 5'd5);
    set_lane(1, 1, 0, 1, 5'd3, 5'd0, 5'd5);   // WAW com lane 0
    set_lane(2, 1, 0, 1, 5'd6, 5'd0, 5'd7);   // independente
    set_lane(3, 1, 0, 1, 5'd5, 5'd0, 5'd9);   // RAW (deve ver o valor da lane 1)
    check_masks(4'b1000, 4'b0010, "WAW antes do leitor");

    // Slot invalido nao gera e nao recebe dependencia.
    set_lane(0, 1, 0, 1, 5'd1, 5'd0, 5'd5);
    set_lane(1, 1, 0, 1, 5'd0, 5'd0, 5'd6);   // escritora de x6 (sera invalidada)
    valid[1] = 1'b0;
    set_lane(2, 1, 0, 1, 5'd5, 5'd0, 5'd7);   // RAW so com a lane 0
    set_lane(3, 1, 0, 1, 5'd6, 5'd0, 5'd8);   // le x6 da lane INVALIDA: sem dep
    check_masks(4'b0100, 4'b0000, "slot invalido descartado");

    // Nao existe lane mais antiga: a lane 0 nunca fica bloqueada.
    set_lane(0, 1, 1, 1, 5'd1, 5'd1, 5'd5);
    set_lane(1, 1, 0, 1, 5'd2, 5'd0, 5'd6);
    set_lane(2, 1, 0, 1, 5'd3, 5'd0, 5'd7);
    set_lane(3, 1, 0, 1, 5'd4, 5'd0, 5'd8);
    check_masks(4'b0000, 4'b0000, "lane 0 nunca bloqueada");

    $display("PASS dependency_checker");
    $finish;
end
endmodule
