/* Unidade de execucao 4-wide: quatro execution_lane identicas.
   Portas empacotadas no mesmo layout das saidas decoded_* do front-end
   (slot i em [i*32 +: 32], [i*5 +: 5], [i*2 +: 2], [i*4 +: 4]).
   A lane i recebe a i-esima instrucao mais velha emitida no ciclo.

   Um desvio tomado em uma lane invalida, no mesmo ciclo, as lanes mais
   jovens: lane_valid = issue_valid sem essas lanes. EX/MEM, LSU e write
   back devem usar lane_valid, nao issue_valid. Entre varios desvios
   tomados vence o mais velho (menor indice).
   redirect tambem deve limpar o que ja entrou no pipeline depois do grupo.
   target_misaligned: o alvo escolhido nao e multiplo de 4 (sem extensao C,
   o fetch nao consegue buscar nele).
   alu_src_pc: AUIPC e a unica instrucao com imediato que nao le rs1.
*/
module execution_unit (
    input  wire [3:0]   issue_valid,
    input  wire [127:0] instruction_pcs,
    input  wire [127:0] immediates,
    input  wire [127:0] rs1_values,
    input  wire [127:0] rs2_values,
    input  wire [19:0]  alu_ops,
    input  wire [3:0]   alu_src_imm,
    input  wire [3:0]   uses_rs1,
    input  wire [7:0]   wb_sels,
    input  wire [15:0]  branch_types,
    output wire [127:0] results,
    output wire [127:0] store_datas,
    output wire [3:0]   lane_valid,
    output wire         redirect,
    output reg  [31:0]  redirect_target,
    output wire         target_misaligned
);
    wire [3:0]   lane_redirect;
    wire [127:0] lane_targets;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : LANE
            execution_lane lane (
                .valid(issue_valid[i]),
                .instruction_pc(instruction_pcs[i*32 +: 32]),
                .immediate(immediates[i*32 +: 32]),
                .rs1_value(rs1_values[i*32 +: 32]),
                .rs2_value(rs2_values[i*32 +: 32]),
                .alu_op(alu_ops[i*5 +: 5]),
                .alu_src_imm(alu_src_imm[i]),
                .alu_src_pc(alu_src_imm[i] & ~uses_rs1[i]),
                .wb_sel(wb_sels[i*2 +: 2]),
                .branch_type(branch_types[i*4 +: 4]),
                .result(results[i*32 +: 32]),
                .store_data(store_datas[i*32 +: 32]),
                .redirect(lane_redirect[i]),
                .redirect_target(lane_targets[i*32 +: 32])
            );
        end
    endgenerate

    assign lane_valid[0] = issue_valid[0];
    assign lane_valid[1] = issue_valid[1] & ~lane_redirect[0];
    assign lane_valid[2] = issue_valid[2] & ~(|lane_redirect[1:0]);
    assign lane_valid[3] = issue_valid[3] & ~(|lane_redirect[2:0]);

    assign redirect = |lane_redirect;

    integer k;
    always @(*) begin
        redirect_target = 32'h00000000;
        for (k = 3; k >= 0; k = k - 1)
            if (lane_redirect[k])
                redirect_target = lane_targets[k*32 +: 32];
    end

    assign target_misaligned = redirect && (redirect_target[1:0] != 2'b00);
endmodule
