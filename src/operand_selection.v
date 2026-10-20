/* Selecao de operandos de uma lane de execucao.
   rs1_fwd/rs2_fwd sao os valores finais de rs1/rs2: alimentam a ALU, a
   branch unit e o dado de store. Enquanto nao houver forwarding, repetem
   a leitura do register file.
   operand_a = PC da instrucao no AUIPC; operand_b = imediato quando
   alu_src_imm (OP-IMM, LOAD, STORE, AUIPC).
*/
module operand_selection (
    input  wire [31:0] rs1_value,
    input  wire [31:0] rs2_value,
    input  wire [31:0] instruction_pc,
    input  wire [31:0] immediate,
    input  wire        alu_src_pc,
    input  wire        alu_src_imm,
    output wire [31:0] rs1_fwd,
    output wire [31:0] rs2_fwd,
    output wire [31:0] operand_a,
    output wire [31:0] operand_b
);
    assign rs1_fwd   = rs1_value;
    assign rs2_fwd   = rs2_value;
    assign operand_a = alu_src_pc  ? instruction_pc : rs1_fwd;
    assign operand_b = alu_src_imm ? immediate      : rs2_fwd;
endmodule
