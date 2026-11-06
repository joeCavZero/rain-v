`timescale 1ns/1ps
/* Hazards do grupo em emissao contra escritas em voo (8 fontes pendentes:
   2 estagios x 4 lanes, fonte 0 = mais recente). Masks por fonte acumuladas
   entre casos, x0 ignorado, WAW informativo, multiplas fontes com o mesmo rd.
*/
module hazard_detection_unit_tb;
reg [3:0] uses_rs1 = 0, uses_rs2 = 0, reg_write = 0;
reg [19:0] rs1 = 0, rs2 = 0, rd = 0;
reg [7:0] pending_valid = 8'b0;
reg [39:0] pending_rd = 40'b0;
wire [31:0] rs1_mask, rs2_mask, waw_mask;
wire [3:0] pending_rs1, pending_rs2, pending_waw;
hazard_detection_unit dut(.*);

function [31:0] maskbit;
    input integer p, i;
    maskbit = 32'd1 << (p*4 + i);
endfunction

// Fonte p pendente: rd
task set_source;
    input integer p;
    input [4:0]  d;
    begin
        pending_valid[p] = 1'b1;
        pending_rd[p*5 +: 5] = d;
    end
endtask

// Lane: usa_rs1(+rs1), usa_rs2(+rs2), escreve(+rd)
task set_lane;
    input integer lane;
    input        u1, u2, wr;
    input [4:0]  a, b, d;
    begin
        uses_rs1[lane] = u1; uses_rs2[lane] = u2; reg_write[lane] = wr;
        rs1[lane*5 +: 5] = a; rs2[lane*5 +: 5] = b; rd[lane*5 +: 5] = d;
    end
endtask

task check_hazards;
    input [3:0]  e1, e2, ew;
    input [31:0] em1, em2, emw;
    input [255:0] msg;
    begin
        #1; // deixa o always @(*) do DUT reavaliar antes de ler
        if (pending_rs1 !== e1 || pending_rs2 !== e2 || pending_waw !== ew ||
            rs1_mask !== em1 || rs2_mask !== em2 || waw_mask !== emw)
            $fatal(1, "%0s: pend rs=%b/%b/%b masks=%h/%h/%h, esperado %b/%b/%b %h/%h/%h",
                   msg, pending_rs1, pending_rs2, pending_waw,
                   rs1_mask, rs2_mask, waw_mask,
                   e1, e2, ew, em1, em2, emw);
    end
endtask

reg [31:0] m0, mw4, m6, mw1;
initial begin
    $dumpfile("target/wave_hazard_detection_unit.vcd"); $dumpvars(0, hazard_detection_unit_tb);

    set_lane(0, 1, 0, 1, 5'd5, 5'd0, 5'd9);  // add lendo x5
    set_lane(1, 1, 1, 0, 5'd7, 5'd7, 5'd0);  // branch lendo x7/x7
    set_lane(2, 1, 0, 1, 5'd5, 5'd0, 5'd9);  // add lendo x5, escreve x9
    set_lane(3, 1, 0, 1, 5'd5, 5'd0, 5'd11); // add lendo x5

    // Sem fontes: nada pendente.
    check_hazards(4'b0000, 4'b0000, 4'b0000, 32'h0, 32'h0, 32'h0, "sem fontes pendentes");

    // Fonte 0 (grupo no estagio MEM) escreve x5: lanes 0, 2 e 3 leem x5;
    // a lane 1 (branch em x7) segue sem pendencia.
    set_source(0, 5'd5);
    m0 = maskbit(0,0) | maskbit(0,2) | maskbit(0,3);
    check_hazards(4'b1101, 4'b0000, 4'b0000, m0, 32'h0, 32'h0, "fonte 0 escreve x5");

    // Fonte 4 (grupo no WB) escreve x7: so a lane 1 fica pendente (rs1 e rs2).
    set_source(4, 5'd7);
    mw4 = maskbit(4,1);
    check_hazards(4'b1111, 4'b0010, 4'b0000, m0 | mw4, mw4, 32'h0, "fonte 4 escreve x7");

    // WAW informativo: as lanes 0 e 2 escrevem x9; fonte 1 pendente no x9.
    set_source(1, 5'd9);
    mw1 = maskbit(1,0) | maskbit(1,2);
    check_hazards(4'b1111, 4'b0010, 4'b0101, m0 | mw4, mw4, mw1, "WAW informativo x9");

    // Duas fontes pendentes com o mesmo rd (x5, fontes 0 e 6): as duas masks.
    set_source(6, 5'd5);
    m6 = maskbit(6,0) | maskbit(6,2) | maskbit(6,3);
    check_hazards(4'b1111, 4'b0010, 4'b0101, m0 | mw4 | m6, mw4, mw1, "duas fontes com x5");

    // Fonte com rd = 0 e fonte invalida: ignoradas (ler x0 nunca depende).
    set_source(7, 5'd0);
    pending_valid[1] = 1'b0;
    check_hazards(4'b1111, 4'b0010, 4'b0000, m0 | mw4 | m6, mw4, 32'h0, "rd 0 e fonte invalida");

    $display("PASS hazard_detection_unit");
    $finish;
end
endmodule
