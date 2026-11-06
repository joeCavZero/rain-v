/* Stall, redirect de desvio e rastro de escritas em voo (inflight_*).
 * stall_out = stall_request && !redirect (redirect silencia o stall do
 * ciclo); redirect/redirect_target passam direto ao front-end, que flusha
 * o buffer e aplica o PC novo. Lanes jovens anuladas por desvio ja saem
 * da execution_unit (lane_valid). Rastro: 2 estagios x 4 lanes = 8 slots,
 * slot = estagio*4 + lane; slot 0 = grupo mais recente, que envelhece um
 * ciclo por borda. push_* deve vir pos-execucao e filtrado (lane_valid &&
 * reg_write && rd != 0). INFLIGHT_STAGES: 0 = backend combinacional,
 * 1 = WB no ciclo seguinte, 2 = MEM e WB no posterior.
 */
module pipeline_control #(
    parameter INFLIGHT_STAGES = 0
) (
    input  wire        clk,
    input  wire        reset,
    // desvio resolvido pela execution_unit neste ciclo
    input  wire        redirect,
    input  wire [31:0] redirect_target,
    // pedido de retencao da issue_unit
    input  wire        stall_request,
    // escritas efetivas deste ciclo (lane_valid && reg_write && rd != 0)
    input  wire [3:0]  push_valid,
    input  wire [19:0] push_rd,      // lane i em [i*5 +: 5]
    output wire        stall_out,    // para o front-end (consumo e fetch param)
    output wire        redirect_out, // para o front-end (PC e flush do buffer)
    output wire [31:0] redirect_target_out,
    output wire [7:0]  inflight_valid, // slot = estagio*4 + lane; 0 = mais recente
    output wire [39:0] inflight_rd
);
    // INFLIGHT_STAGES permitido: 0, 1 ou 2 (limitado a 2 estagios de rastro).
    localparam integer STAGES = (INFLIGHT_STAGES > 2) ? 2 : INFLIGHT_STAGES;

    reg [3:0]  stage_valid [0:1];
    reg [19:0] stage_rd    [0:1];

    integer s;
    always @(posedge clk) begin
        if (reset || (STAGES == 0)) begin
            stage_valid[0] <= 4'b0;
            stage_valid[1] <= 4'b0;
            stage_rd[0] <= 20'b0;
            stage_rd[1] <= 20'b0;
        end else begin
            if (STAGES > 1) begin
                stage_valid[1] <= stage_valid[0];
                stage_rd[1] <= stage_rd[0];
            end
            stage_valid[0] <= push_valid;
            stage_rd[0] <= push_rd;
        end
    end

    // Saidas publicam so os estagios existentes; o resto fica zerado (as
    // hazard/forwarding units esperam o comprimento fixo de 8 fontes).
    genvar g;
    generate
        for (g = 0; g < 2; g = g + 1) begin : STAGE_OUTPUT
            if (g < STAGES) begin
                assign inflight_valid[g*4 +: 4] = stage_valid[g];
                assign inflight_rd[g*20 +: 20] = stage_rd[g];
            end else begin
                assign inflight_valid[g*4 +: 4] = 4'b0;
                assign inflight_rd[g*20 +: 20] = 20'b0;
            end
        end
    endgenerate

    assign stall_out = stall_request && !redirect;
    assign redirect_out = redirect;
    assign redirect_target_out = redirect_target;
endmodule
