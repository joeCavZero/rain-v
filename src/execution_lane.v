/* Lane de execucao: executa uma instrucao por ciclo, de forma combinacional.
   instruction_pc e o PC da propria instrucao (decoded_pcs[i]), nao o PC de
   fetch do front-end.
   result: wb_sel 0 = ALU, 2 = PC+4 (JAL/JALR), 3 = imediato (LUI). Em load e
   store, result e o endereco efetivo (rs1 + imediato); com wb_sel = 1 o write
   back troca result pelo dado lido da memoria.
   store_data = rs2 final (pos-forwarding).
   redirect = valid && desvio tomado; redirect_target e o PC correto.
   valid significa: emitida pelo Issue neste ciclo, com operandos prontos.
*/
module execution_lane (
    input  wire        valid,
    input  wire [31:0] instruction_pc,
    input  wire [31:0] immediate,
    input  wire [31:0] rs1_value,
    input  wire [31:0] rs2_value,
    input  wire [4:0]  alu_op,
    input  wire        alu_src_imm,
    input  wire        alu_src_pc,
    input  wire [1:0]  wb_sel,
    input  wire [3:0]  branch_type,
    output reg  [31:0] result,
    output wire [31:0] store_data,
    output wire        redirect,
    output wire [31:0] redirect_target
);
    localparam WB_PC_PLUS_4 = 2'd2;
    localparam WB_IMMEDIATE = 2'd3;

    wire [31:0] rs1_fwd;
    wire [31:0] rs2_fwd;
    wire [31:0] operand_a;
    wire [31:0] operand_b;
    wire [31:0] alu_result;

    operand_selection operands (
        .rs1_value(rs1_value),
        .rs2_value(rs2_value),
        .instruction_pc(instruction_pc),
        .immediate(immediate),
        .alu_src_pc(alu_src_pc),
        .alu_src_imm(alu_src_imm),
        .rs1_fwd(rs1_fwd),
        .rs2_fwd(rs2_fwd),
        .operand_a(operand_a),
        .operand_b(operand_b)
    );

    arithmetic_logic_unit alu (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .op(alu_op),
        .result(alu_result)
    );

    branch_unit branch (
        .valid(valid),
        .branch_type(branch_type),
        .instruction_pc(instruction_pc),
        .immediate(immediate),
        .rs1_value(rs1_fwd),
        .rs2_value(rs2_fwd),
        .taken(),
        .target(redirect_target),
        .redirect(redirect)
    );

    always @(*) begin
        case (wb_sel)
            WB_PC_PLUS_4: result = instruction_pc + 32'd4;
            WB_IMMEDIATE: result = immediate;
            default:      result = alu_result;
        endcase
    end

    assign store_data = rs2_fwd;
endmodule
