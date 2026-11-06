/* Bypass de operandos: substitui o valor lido do banco pelo resultado
 * que ja existe das escritas em voo (fonte p: source_valid[p], rd em
 * [p*5 +: 5], data em [p*32 +: 32]). Vence a fonte de menor indice (a
 * escrita mais recente). x0 nunca e encaminhado. pending_* vem da hazard
 * unit (toda escrita em voo); rs*_resolved = 1 quando o operando esta
 * pronto: sem pendencia, ou pendencia coberta pela fonte.
 */
module forwarding_unit #(
    parameter SOURCES = 8
) (
    input  wire [3:0]             uses_rs1, uses_rs2,
    input  wire [19:0]            rs1, rs2,
    // valores lidos do banco de registradores (fallback, 32 bits por lane)
    input  wire [127:0]           rs1_bank, rs2_bank,
    input  wire [3:0]             pending_rs1, pending_rs2, // hazards da hazard_detection_unit
    input  wire [SOURCES-1:0]     source_valid,   // fonte entrega o resultado neste ciclo
    input  wire [5*SOURCES-1:0]   source_rd,
    input  wire [32*SOURCES-1:0]  source_data,
    output reg  [127:0]           rs1_values, rs2_values,
    output wire [3:0]             rs1_forwarded, rs2_forwarded,
    output wire [3:0]             rs1_resolved, rs2_resolved
);
    reg [3:0] hit_rs1, hit_rs2;
    integer p;
    integer i;

    always @(*) begin
        rs1_values = rs1_bank;
        rs2_values = rs2_bank;
        hit_rs1 = 4'b0;
        hit_rs2 = 4'b0;
        for (p = 0; p < SOURCES; p = p + 1)
            if (source_valid[p] && (source_rd[p*5 +: 5] != 5'd0))
                for (i = 0; i < 4; i = i + 1) begin
                    if (uses_rs1[i] && !hit_rs1[i] &&
                        (rs1[i*5 +: 5] == source_rd[p*5 +: 5])) begin
                        rs1_values[i*32 +: 32] = source_data[p*32 +: 32];
                        hit_rs1[i] = 1'b1;
                    end
                    if (uses_rs2[i] && !hit_rs2[i] &&
                        (rs2[i*5 +: 5] == source_rd[p*5 +: 5])) begin
                        rs2_values[i*32 +: 32] = source_data[p*32 +: 32];
                        hit_rs2[i] = 1'b1;
                    end
                end
    end

    assign rs1_forwarded = hit_rs1;
    assign rs2_forwarded = hit_rs2;
    // Sem pendencia, ou pendencia coberta pela fonte: operando pronto.
    assign rs1_resolved = (~uses_rs1) | hit_rs1 | (~pending_rs1);
    assign rs2_resolved = (~uses_rs2) | hit_rs2 | (~pending_rs2);
endmodule
