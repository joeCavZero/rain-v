`timescale 1ns/1ps
/* Instrucoes reais passam pelo instruction_decoder e os operandos vem de um
   banco de registradores do proprio testbench, como sera na integracao. */
module execution_lane_tb;
reg valid;
reg [31:0] instruction, instruction_pc;
reg [31:0] regs [0:31];

wire [4:0] rs1, rs2, rd, alu_op;
wire uses_rs1, uses_rs2, reg_write, mem_read, mem_write, alu_src_imm, illegal;
wire [1:0] wb_sel;
wire [3:0] branch_type;
wire [31:0] immediate;
instruction_decoder decoder(.*);

// AUIPC e a unica instrucao com imediato que nao le rs1.
wire alu_src_pc = alu_src_imm & ~uses_rs1;
wire [31:0] rs1_value = regs[rs1];
wire [31:0] rs2_value = regs[rs2];
wire [31:0] result, store_data, redirect_target;
wire redirect;

execution_lane lane (
    .valid(valid),
    .instruction_pc(instruction_pc),
    .immediate(immediate),
    .rs1_value(rs1_value),
    .rs2_value(rs2_value),
    .alu_op(alu_op),
    .alu_src_imm(alu_src_imm),
    .alu_src_pc(alu_src_pc),
    .wb_sel(wb_sel),
    .branch_type(branch_type),
    .result(result),
    .store_data(store_data),
    .redirect(redirect),
    .redirect_target(redirect_target)
);

localparam OP = 7'b0110011, OP_IMM = 7'b0010011, LOAD = 7'b0000011,
           JALR_OP = 7'b1100111, LUI = 7'b0110111, AUIPC = 7'b0010111;

// Montadores de instrucao RV32I.
function [31:0] r_type;
    input [6:0] f_funct7; input [4:0] f_rs2, f_rs1; input [2:0] f_funct3; input [4:0] f_rd;
    r_type = {f_funct7, f_rs2, f_rs1, f_funct3, f_rd, OP};
endfunction
function [31:0] i_type;
    input [11:0] f_imm; input [4:0] f_rs1; input [2:0] f_funct3; input [4:0] f_rd; input [6:0] f_opcode;
    i_type = {f_imm, f_rs1, f_funct3, f_rd, f_opcode};
endfunction
function [31:0] s_type;
    input [11:0] f_imm; input [4:0] f_rs2, f_rs1; input [2:0] f_funct3;
    s_type = {f_imm[11:5], f_rs2, f_rs1, f_funct3, f_imm[4:0], 7'b0100011};
endfunction
function [31:0] b_type;
    input [12:0] f_imm; input [4:0] f_rs2, f_rs1; input [2:0] f_funct3;
    b_type = {f_imm[12], f_imm[10:5], f_rs2, f_rs1, f_funct3, f_imm[4:1], f_imm[11], 7'b1100011};
endfunction
function [31:0] u_type;
    input [19:0] f_imm; input [4:0] f_rd; input [6:0] f_opcode;
    u_type = {f_imm, f_rd, f_opcode};
endfunction
function [31:0] j_type;
    input [20:0] f_imm; input [4:0] f_rd;
    j_type = {f_imm[20], f_imm[10:1], f_imm[11], f_imm[19:12], f_rd, 7'b1101111};
endfunction

task run;
    input [31:0] word, pc, expected_result;
    begin
        instruction = word; instruction_pc = pc; #1;
        if (illegal) $fatal(1, "%h decodificou como ilegal", word);
        if (result !== expected_result)
            $fatal(1, "instrucao %h (pc=%h): result=%h, esperado %h", word, pc, result, expected_result);
        if (branch_type == 4'd0 && redirect !== 1'b0)
            $fatal(1, "instrucao %h sem desvio gerou redirect", word);
    end
endtask

task run_branch;
    input [31:0] word, pc;
    input        expected_redirect;
    input [31:0] expected_target;
    begin
        instruction = word; instruction_pc = pc; #1;
        if (illegal) $fatal(1, "%h decodificou como ilegal", word);
        if (redirect !== expected_redirect ||
            (expected_redirect && redirect_target !== expected_target))
            $fatal(1, "desvio %h (pc=%h): redirect=%b target=%h, esperado redirect=%b target=%h",
                   word, pc, redirect, redirect_target, expected_redirect, expected_target);
    end
endtask

task run_store;
    input [31:0] word, expected_address, expected_data;
    begin
        run(word, 32'h0, expected_address);
        if (store_data !== expected_data)
            $fatal(1, "store %h: store_data=%h, esperado %h", word, store_data, expected_data);
    end
endtask

integer k;

initial begin
    $dumpfile("target/wave.vcd"); $dumpvars(0, execution_lane_tb);

    valid = 1;
    for (k = 0; k < 32; k = k + 1) regs[k] = 32'hA5A50000 | k;
    regs[0] = 32'h00000000;
    regs[1] = 32'h00000005;
    regs[2] = 32'h00000007;
    regs[3] = 32'hFFFFFFFD;   // -3
    regs[4] = 32'h80000000;
    regs[5] = 32'h00001000;   // base de enderecos
    regs[6] = 32'h12345678;
    regs[7] = 32'h0000001F;   // 31
    regs[8] = 32'hFFFFFFFF;   // -1

    // Os montadores reproduzem as palavras dos testbenches do decoder.
    if (r_type(7'b0, 5'd3, 5'd2, 3'b000, 5'd1) !== 32'h003100b3 ||
        i_type(12'hFFF, 5'd0, 3'b000, 5'd1, OP_IMM) !== 32'hfff00093 ||
        i_type(12'h000, 5'd2, 3'b010, 5'd1, LOAD) !== 32'h00012083 ||
        s_type(12'h000, 5'd1, 5'd2, 3'b010) !== 32'h00112023 ||
        b_type(13'd8, 5'd0, 5'd0, 3'b000) !== 32'h00000463 ||
        j_type(21'd8, 5'd1) !== 32'h008000ef ||
        u_type(20'h12345, 5'd1, LUI) !== 32'h123450b7)
        $fatal(1, "montador de instrucao diferente das palavras de referencia");

    // Palavras de referencia dos testbenches do decoder.
    run(32'h003100b3, 32'h0, 32'h00000004);   // add x1,x2,x3   = 7 + (-3)
    run(32'hfff00093, 32'h0, 32'hFFFFFFFF);   // addi x1,x0,-1
    run(32'h00012083, 32'h0, 32'h00000007);   // lw x1,0(x2): endereco
    run_store(32'h00112023, 32'h00000007, 32'h00000005); // sw x1,0(x2)
    run(32'h123450b7, 32'h0, 32'h12345000);   // lui x1,0x12345
    run(32'h008000ef, 32'h200, 32'h00000204); // jal x1,+8: PC+4

    // Tipo R.
    run(r_type(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd9), 32'h0, 32'h0000000C); // add
    run(r_type(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd9), 32'h0, 32'hFFFFFFFE); // sub
    run(r_type(7'b0000000, 5'd7, 5'd1, 3'b001, 5'd9), 32'h0, 32'h80000000); // sll 5<<31
    run(r_type(7'b0000000, 5'd1, 5'd3, 3'b010, 5'd9), 32'h0, 32'h00000001); // slt -3<5
    run(r_type(7'b0000000, 5'd1, 5'd3, 3'b011, 5'd9), 32'h0, 32'h00000000); // sltu
    run(r_type(7'b0000000, 5'd8, 5'd6, 3'b100, 5'd9), 32'h0, 32'hEDCBA987); // xor
    run(r_type(7'b0000000, 5'd7, 5'd4, 3'b101, 5'd9), 32'h0, 32'h00000001); // srl
    run(r_type(7'b0100000, 5'd7, 5'd4, 3'b101, 5'd9), 32'h0, 32'hFFFFFFFF); // sra
    run(r_type(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd9), 32'h0, 32'h00000007); // or
    run(r_type(7'b0000000, 5'd8, 5'd6, 3'b111, 5'd9), 32'h0, 32'h12345678); // and

    // Tipo I aritmetico. SRAI leva 0100000 nos bits altos do imediato.
    run(i_type(12'hFFF, 5'd1, 3'b000, 5'd9, OP_IMM), 32'h0, 32'h00000004); // addi 5-1
    run(i_type(12'hFFE, 5'd3, 3'b010, 5'd9, OP_IMM), 32'h0, 32'h00000001); // slti -3<-2
    run(i_type(12'hFFF, 5'd0, 3'b011, 5'd9, OP_IMM), 32'h0, 32'h00000001); // sltiu 0<FFFFFFFF
    run(i_type(12'hFFF, 5'd6, 3'b100, 5'd9, OP_IMM), 32'h0, 32'hEDCBA987); // xori
    run(i_type(12'h0F0, 5'd1, 3'b110, 5'd9, OP_IMM), 32'h0, 32'h000000F5); // ori
    run(i_type(12'h0FF, 5'd6, 3'b111, 5'd9, OP_IMM), 32'h0, 32'h00000078); // andi
    run(i_type(12'h004, 5'd1, 3'b001, 5'd9, OP_IMM), 32'h0, 32'h00000050); // slli
    run(i_type(12'h004, 5'd4, 3'b101, 5'd9, OP_IMM), 32'h0, 32'h08000000); // srli
    run(i_type(12'h404, 5'd4, 3'b101, 5'd9, OP_IMM), 32'h0, 32'hF8000000); // srai

    // Tipo U: AUIPC soma o PC da propria instrucao.
    run(u_type(20'h12345, 5'd9, LUI),   32'h100, 32'h12345000);
    run(u_type(20'h00001, 5'd9, AUIPC), 32'h100, 32'h00001100);
    run(u_type(20'hFFFFF, 5'd9, AUIPC), 32'h100, 32'hFFFFF100);

    // Load e store: result e o endereco; store_data e rs2.
    run(i_type(12'h008, 5'd5, 3'b010, 5'd9, LOAD), 32'h0, 32'h00001008);  // lw 8(x5)
    run(i_type(12'hFFC, 5'd5, 3'b000, 5'd9, LOAD), 32'h0, 32'h00000FFC);  // lb -4(x5)
    run_store(s_type(12'h00C, 5'd6, 5'd5, 3'b010), 32'h0000100C, 32'h12345678); // sw
    run_store(s_type(12'hFFF, 5'd8, 5'd5, 3'b000), 32'h00000FFF, 32'hFFFFFFFF); // sb

    // Extensao M.
    run(r_type(7'b0000001, 5'd2, 5'd3, 3'b000, 5'd9), 32'h0, 32'hFFFFFFEB); // mul -3*7
    run(r_type(7'b0000001, 5'd1, 5'd8, 3'b001, 5'd9), 32'h0, 32'hFFFFFFFF); // mulh -1*5
    run(r_type(7'b0000001, 5'd8, 5'd3, 3'b010, 5'd9), 32'h0, 32'hFFFFFFFD); // mulhsu
    run(r_type(7'b0000001, 5'd1, 5'd8, 3'b011, 5'd9), 32'h0, 32'h00000004); // mulhu

    // JAL e JALR escrevem PC+4.
    run(j_type(21'h1FFFF0, 5'd1), 32'h300, 32'h00000304);                   // jal -16
    run(i_type(12'h000, 5'd5, 3'b000, 5'd1, JALR_OP), 32'h400, 32'h00000404); // jalr

    // Desvios condicionais: x1=5, x2=7, x3=-3.
    run_branch(32'h00000463, 32'h100, 1, 32'h00000108);                      // beq x0,x0,+8
    run_branch(b_type(13'd16,    5'd2, 5'd1, 3'b000), 32'h100, 0, 32'h0);    // beq 5,7
    run_branch(b_type(13'h1FF8,  5'd2, 5'd1, 3'b001), 32'h100, 1, 32'hF8);   // bne -8
    run_branch(b_type(13'd32,    5'd1, 5'd3, 3'b100), 32'h100, 1, 32'h120);  // blt -3<5
    run_branch(b_type(13'd32,    5'd1, 5'd3, 3'b110), 32'h100, 0, 32'h0);    // bltu
    run_branch(b_type(13'd64,    5'd3, 5'd1, 3'b101), 32'h100, 1, 32'h140);  // bge 5>=-3
    run_branch(b_type(13'd64,    5'd3, 5'd1, 3'b111), 32'h100, 0, 32'h0);    // bgeu

    // Saltos: JAL relativo ao PC; JALR = (rs1 + imm) com bit 0 zerado.
    run_branch(32'h008000ef, 32'h200, 1, 32'h00000208);                      // jal +8
    run_branch(j_type(21'h1FFFF0, 5'd1), 32'h300, 1, 32'h000002F0);          // jal -16
    run_branch(i_type(12'h003, 5'd5, 3'b000, 5'd1, JALR_OP), 32'h400, 1, 32'h00001002);
    run_branch(i_type(12'hFFC, 5'd5, 3'b000, 5'd0, JALR_OP), 32'h400, 1, 32'h00000FFC);

    // valid=0 nunca redireciona.
    valid = 0;
    run_branch(32'h008000ef, 32'h200, 0, 32'h0);
    valid = 1;

    // Instrucao ilegal: o decoder zera os controles, entao nao ha desvio.
    instruction = 32'hffffffff; instruction_pc = 32'h500; #1;
    if (!illegal || redirect !== 1'b0) $fatal(1, "instrucao ilegal nao pode redirecionar");

    $display("PASS execution_lane");
    $finish;
end
endmodule
