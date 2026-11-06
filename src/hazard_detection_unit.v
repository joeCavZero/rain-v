/* RAW e WAW do grupo em emissao contra escritas em voo (fontes 0..7:
 * 2 estagios x 4 lanes, fonte 0 = grupo mais recente). As fontes vem do
 * rastro inflight_* da pipeline_control; fonte com rd 0 e ignorada (ler x0
 * nunca depende). Mask da fonte p: bits p*4..p*4+3 (lane i);
 * pending_* agrega por lane (qualquer fonte). Recebe TODA escrita em voo,
 * mesmo sem dado; o forwarding recebe so as com dado e o rs*_resolved
 * decide o que a issue_unit pode emitir (INFLIGHT_STAGES=0: inerte).
 */
module hazard_detection_unit #(
    parameter PENDINGS = 8
) (
    input  wire [3:0]              uses_rs1, uses_rs2, reg_write,
    input  wire [19:0]             rs1, rs2, rd,
    input  wire [PENDINGS-1:0]     pending_valid, // fonte p tem escrita em voo
    input  wire [5*PENDINGS-1:0]   pending_rd,
    output wire [4*PENDINGS-1:0]   rs1_mask, rs2_mask, waw_mask,
    output wire [3:0]              pending_rs1, pending_rs2, pending_waw
);
    reg [PENDINGS*4-1:0] rs1_bits, rs2_bits, waw_bits;
    reg [3:0] p_rs1_bits, p_rs2_bits, p_waw_bits;
    integer p;
    integer i;

    always @(*) begin
        rs1_bits = {(PENDINGS*4){1'b0}};
        rs2_bits = {(PENDINGS*4){1'b0}};
        waw_bits = {(PENDINGS*4){1'b0}};
        p_rs1_bits = 4'b0;
        p_rs2_bits = 4'b0;
        p_waw_bits = 4'b0;
        for (p = 0; p < PENDINGS; p = p + 1)
            if (pending_valid[p] && (pending_rd[p*5 +: 5] != 5'd0))
                for (i = 0; i < 4; i = i + 1) begin
                    if (uses_rs1[i] && (rs1[i*5 +: 5] == pending_rd[p*5 +: 5])) begin
                        rs1_bits[p*4 + i] = 1'b1;
                        p_rs1_bits[i] = 1'b1;
                    end
                    if (uses_rs2[i] && (rs2[i*5 +: 5] == pending_rd[p*5 +: 5])) begin
                        rs2_bits[p*4 + i] = 1'b1;
                        p_rs2_bits[i] = 1'b1;
                    end
                    if (reg_write[i] && (rd[i*5 +: 5] == pending_rd[p*5 +: 5])) begin
                        waw_bits[p*4 + i] = 1'b1;
                        p_waw_bits[i] = 1'b1;
                    end
                end
    end

    assign rs1_mask = rs1_bits;
    assign rs2_mask = rs2_bits;
    assign waw_mask = waw_bits;
    assign pending_rs1 = p_rs1_bits;
    assign pending_rs2 = p_rs2_bits;
    assign pending_waw = p_waw_bits;
endmodule
