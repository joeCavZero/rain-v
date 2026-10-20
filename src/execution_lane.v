/* Lane de execucao: executa uma instrucao por ciclo, de forma combinacional.
   instruction_pc e o PC da propria instrucao (decoded_pcs[i]), nao o PC de
   fetch do front-end.
   result: wb_sel 0 = ALU, 2 = PC+4 (JAL/JALR), 3 = imediato (LUI). Em load e
   store, result e o endereco efetivo (rs1 + imediato); com wb_sel = 1 o write
   back troca result pelo dado lido da memoria.
   store_data = rs2 final (pos-forwarding).
*/
module execution_lane (
    input  wire [31:0] instruction_pc,
    input  wire [31:0] immediate,
    input  wire [31:0] rs1_value,
    input  wire [31:0] rs2_value,
    input  wire [4:0]  alu_op,
    input  wire        alu_src_imm,
    input  wire        alu_src_pc,
    input  wire [1:0]  wb_sel,
    output reg  [31:0] result,
    output wire [31:0] store_data
);
    localparam WB_PC_PLUS_4 = 2'd2;
    localparam WB_IMMEDIATE = 2'd3;

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
        .rs1_fwd(),
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

    always @(*) begin
        case (wb_sel)
            WB_PC_PLUS_4: result = instruction_pc + 32'd4;
            WB_IMMEDIATE: result = immediate;
            default:      result = alu_result;
        endcase
    end

    assign store_data = rs2_fwd;
endmodule
