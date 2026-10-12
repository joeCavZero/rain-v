/* FRONT-END INTEGRAVEL (nao e uma CPU completa).
   O modulo fornece ate 4 instrucoes decodificadas para a Issue Unit externa.
   issue_count informa quantas instrucoes consecutivas foram ACEITAS pelo backend.
   Nao implementa execucao, commit, LSU, forwarding ou hazards.
   Contrato: nao emitir branch/jump e instrucao mais jovem no mesmo grupo
   sem tratamento de redirecionamento/flush pelo backend.
*/
module central_processing_unit #(
    parameter IMEM_WORDS=256,
    parameter IMEM_FILE=""
) (
    input wire clk, reset,
    input wire stall,
    input wire redirect,
    input wire [31:0] redirect_target,
    input wire [2:0] issue_count,
    output wire [31:0] pc,
    output wire [127:0] decoded_instructions,
    output wire [127:0] decoded_pcs,
    output wire [3:0] decoded_valid,
    output wire [19:0] decoded_rs1, decoded_rs2, decoded_rd, decoded_alu_op,
    output wire [127:0] decoded_immediate,
    output wire [3:0] decoded_uses_rs1, decoded_uses_rs2,
    output wire [3:0] decoded_reg_write, decoded_mem_read, decoded_mem_write,
    output wire [3:0] decoded_alu_src_imm, decoded_illegal,
    output wire [7:0] decoded_wb_sel,
    output wire [15:0] decoded_branch_type
);
    wire [127:0] fetched_instructions;
    wire [3:0] fetched_valid;
    wire [127:0] fetched_pcs;
    wire buffer_empty;
    wire fetch_enable = buffer_empty && !stall && !redirect;
    wire [2:0] safe_issue_count = issue_count>4 ? 3'd4 : issue_count;
    program_counter pc_unit(.clk(clk),.reset(reset),.enable(fetch_enable),
        .redirect(redirect),.redirect_target(redirect_target),
        .advance_words(3'd4),.value(pc));
    instruction_fetch #(.WORDS(IMEM_WORDS),.INIT_FILE(IMEM_FILE)) fetch_unit (
        .pc(pc),.instructions(fetched_instructions),.valid(fetched_valid));
    genvar i;
    generate for(i=0;i<4;i=i+1) begin: FETCH_PC
        assign fetched_pcs[i*32 +: 32]=pc+(i*4);
    end endgenerate
    pipeline_registers buffer_unit(.clk(clk),.reset(reset),.flush(redirect),
        .stall(stall),.load(fetch_enable),.consume_count(safe_issue_count),
        .instructions_in(fetched_instructions),.pc_in(fetched_pcs),.valid_in(fetched_valid),
        .instructions_out(decoded_instructions),.pc_out(decoded_pcs),
        .valid_out(decoded_valid),.empty(buffer_empty));
    generate for(i=0;i<4;i=i+1) begin: DECODE
        instruction_decoder decoder (
            .instruction(decoded_instructions[i*32 +: 32]),
            .rs1(decoded_rs1[i*5 +: 5]),.rs2(decoded_rs2[i*5 +: 5]),
            .rd(decoded_rd[i*5 +: 5]),
            .uses_rs1(decoded_uses_rs1[i]),.uses_rs2(decoded_uses_rs2[i]),
            .reg_write(decoded_reg_write[i]),.mem_read(decoded_mem_read[i]),
            .mem_write(decoded_mem_write[i]),.alu_src_imm(decoded_alu_src_imm[i]),
            .illegal(decoded_illegal[i]),.alu_op(decoded_alu_op[i*5 +: 5]),
            .wb_sel(decoded_wb_sel[i*2 +: 2]),
            .branch_type(decoded_branch_type[i*4 +: 4]),
            .immediate(decoded_immediate[i*32 +: 32]));
    end endgenerate
endmodule
