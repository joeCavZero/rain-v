/* Branch unit RV32I. Resolve o desvio no estagio de execucao; o front-end
   busca sempre em sequencia (predicao not taken), entao todo desvio tomado
   gera redirect.
   branch_type: 0=nenhum 1=BEQ 2=BNE 3=BLT 4=BGE 5=BLTU 6=BGEU 7=JAL 8=JALR.
   rs1_value/rs2_value ja sao os operandos finais (pos-forwarding).
   taken e o resultado real, sem filtro de valid; redirect = valid && taken.
   Alvo: PC da instrucao + imediato; no JALR, (rs1 + imediato) com bit 0
   zerado. Um somador so, com a base escolhida por mux.
*/
module branch_unit (
    input  wire        valid,
    input  wire [3:0]  branch_type,
    input  wire [31:0] instruction_pc,
    input  wire [31:0] immediate,
    input  wire [31:0] rs1_value,
    input  wire [31:0] rs2_value,
    output reg         taken,
    output wire [31:0] target,
    output wire        redirect
);
    localparam BEQ  = 4'd1;
    localparam BNE  = 4'd2;
    localparam BLT  = 4'd3;
    localparam BGE  = 4'd4;
    localparam BLTU = 4'd5;
    localparam BGEU = 4'd6;
    localparam JAL  = 4'd7;
    localparam JALR = 4'd8;

    wire is_jalr = branch_type == JALR;

    wire [31:0] target_base = is_jalr ? rs1_value : instruction_pc;
    wire [31:0] target_sum  = target_base + immediate;

    wire equal         = rs1_value == rs2_value;
    wire less_signed   = $signed(rs1_value) < $signed(rs2_value);
    wire less_unsigned = rs1_value < rs2_value;

    always @(*) begin
        case (branch_type)
            BEQ:     taken = equal;
            BNE:     taken = !equal;
            BLT:     taken = less_signed;
            BGE:     taken = !less_signed;
            BLTU:    taken = less_unsigned;
            BGEU:    taken = !less_unsigned;
            JAL:     taken = 1'b1;
            JALR:    taken = 1'b1;
            default: taken = 1'b0;
        endcase
    end

    assign target   = is_jalr ? {target_sum[31:1], 1'b0} : target_sum;
    assign redirect = valid && taken;
endmodule
