/* Emissor in-order do grupo de 4: emite so o prefixo consecutivo pronto,
 * parado ao primeiro obstaculo (nunca reordena). Lane emitida quando:
 * valida, nao ilegal, sem RAW in-group (raw_group) e operandos resolvidos
 * (rs*_resolved). Ilegal e no-op: consome o slot sem executar e a emissao
 * passa por ela. Slot invalido encerra o prefixo (buffer compactado).
 * Exemplo do plano (add/sub/and/or): emite 1 e depois 3. Branch + jovens
 * no grupo: execution_unit anula as jovens. Combinacional. stall_request:
 * grupo valido e nada emitido (pipeline_control silencia no redirect).
 */
module issue_unit (
    input  wire [3:0] group_valid,          // decoded_valid do front-end
    input  wire [3:0] illegal,              // decoded_illegal do front-end
    input  wire [3:0] raw_group,            // dependency_checker: RAW in-group
    input  wire [3:0] rs1_resolved, rs2_resolved, // forwarding_unit
    output wire [3:0] issue_valid,          // lanes que executam neste ciclo
    output wire [3:0] consumed,             // lanes retiradas do grupo (emitidas + ilegais)
    output wire [2:0] issue_count,          // decimal de consumed (0..4)
    output wire        stall_request        // grupo valido e nada emitido
);
    // Operando pendente sem cobertura do forwarding: lane bloqueada.
    wire [3:0] pending_block = (~rs1_resolved) | (~rs2_resolved);

    // Cadeia in-order: consumed[i] exige todas as anteriores consumidas.
    assign consumed[0] = group_valid[0] & (~pending_block[0]) & (~raw_group[0]);
    assign consumed[1] = consumed[0] & group_valid[1] &
                         (~pending_block[1]) & ((~raw_group[1]) | illegal[1]);
    assign consumed[2] = consumed[1] & group_valid[2] &
                         (~pending_block[2]) & ((~raw_group[2]) | illegal[2]);
    assign consumed[3] = consumed[2] & group_valid[3] &
                         (~pending_block[3]) & ((~raw_group[3]) | illegal[3]);

    // Emitidas = consumidas que nao sao no-op ilegal.
    assign issue_valid = consumed & (~illegal);

    // consumed e sempre um prefixo pronto (0000, 0001, 0011, 0111, 1111):
    // a soma dos bits da o numero de lanes consumidas (maximo 4 cabe em 3 bits).
    assign issue_count = consumed[0] + consumed[1] + consumed[2] + consumed[3];

    assign stall_request = group_valid[0] & (issue_count == 3'd0);
endmodule
