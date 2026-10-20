`timescale 1ns/1ps

module arithmetic_logic_unit_tb;

    // ------------------------------------------------------------
    // Entradas da ALU
    // ------------------------------------------------------------

    reg  [31:0] operand_a;
    reg  [31:0] operand_b;
    reg  [4:0]  op;

    // ------------------------------------------------------------
    // Saída da ALU
    // ------------------------------------------------------------

    wire [31:0] result;


    // ------------------------------------------------------------
    // Códigos das operações.
    //
    // Devem ser iguais aos definidos em arithmetic_logic_unit.v.
    // ------------------------------------------------------------

    localparam ALU_ADD    = 5'd0;
    localparam ALU_SUB    = 5'd1;

    localparam ALU_SLL    = 5'd2;
    localparam ALU_SLT    = 5'd3;
    localparam ALU_SLTU   = 5'd4;

    localparam ALU_XOR    = 5'd5;
    localparam ALU_SRL    = 5'd6;
    localparam ALU_SRA    = 5'd7;

    localparam ALU_OR     = 5'd8;
    localparam ALU_AND    = 5'd9;

    localparam ALU_MUL    = 5'd10;
    localparam ALU_MULH   = 5'd11;
    localparam ALU_MULHSU = 5'd12;
    localparam ALU_MULHU  = 5'd13;


    // ------------------------------------------------------------
    // Instância da ALU que será testada.
    // ------------------------------------------------------------

    arithmetic_logic_unit dut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .op(op),
        .result(result)
    );


    // ------------------------------------------------------------
    // Contadores dos testes.
    // ------------------------------------------------------------

    integer tests;
    integer passed;
    integer failed;


    // ------------------------------------------------------------
    // Estado do teste aleatório.
    // ------------------------------------------------------------

    localparam RANDOM_ITERATIONS = 20000;

    reg [31:0] random_state;
    reg [2:0]  selector;
    reg [31:0] expected;
    integer    iteration;


    // ------------------------------------------------------------
    // Task utilizada para executar um teste.
    //
    // Recebe:
    //
    //     operação
    //     operando A
    //     operando B
    //     resultado esperado
    //
    // Depois compara o resultado produzido pela ALU.
    // ------------------------------------------------------------

    task check;
        input [4:0]  test_op;
        input [31:0] test_a;
        input [31:0] test_b;
        input [31:0] expected;

        begin

            op        = test_op;
            operand_a = test_a;
            operand_b = test_b;

            // A ALU é combinacional.
            //
            // Portanto, basta esperar um pequeno tempo para
            // permitir a propagação do resultado.
            #1;

            tests = tests + 1;

            if (result === expected) begin

                passed = passed + 1;

                $display(
                    "PASSOU | op=%0d | a=%h | b=%h | result=%h",
                    test_op,
                    test_a,
                    test_b,
                    result
                );

            end else begin

                failed = failed + 1;

                $display(
                    "FALHOU | op=%0d | a=%h | b=%h | esperado=%h | recebido=%h",
                    test_op,
                    test_a,
                    test_b,
                    expected,
                    result
                );

            end

        end
    endtask


    // ------------------------------------------------------------
    // Modelo de referência para o teste aleatório.
    //
    // Escrito de forma diferente da ALU de propósito: shifts bit a
    // bit, comparações pelo borrow da subtração e produtos em 64
    // bits com extensão de sinal explícita.
    // ------------------------------------------------------------

    function [31:0] reference_alu;
        input [4:0]  f_op;
        input [31:0] f_a;
        input [31:0] f_b;

        reg [31:0] value;
        reg [32:0] difference;
        reg [63:0] wide_a;
        reg [63:0] wide_b;
        reg [63:0] product;
        integer    k;

        begin
            value      = f_a;
            difference = {1'b0, f_a} - {1'b0, f_b};
            wide_a     = {32'b0, f_a};
            wide_b     = {32'b0, f_b};

            case (f_op)
                ALU_ADD: reference_alu = f_a + f_b;
                ALU_SUB: reference_alu = f_a + ~f_b + 32'd1;

                ALU_SLL: begin
                    for (k = 0; k < f_b[4:0]; k = k + 1)
                        value = {value[30:0], 1'b0};
                    reference_alu = value;
                end

                ALU_SRL: begin
                    for (k = 0; k < f_b[4:0]; k = k + 1)
                        value = {1'b0, value[31:1]};
                    reference_alu = value;
                end

                ALU_SRA: begin
                    for (k = 0; k < f_b[4:0]; k = k + 1)
                        value = {value[31], value[31:1]};
                    reference_alu = value;
                end

                // Sinais diferentes: A é menor se for negativo.
                // Sinais iguais: vale a comparação sem sinal.
                ALU_SLT: reference_alu = (f_a[31] != f_b[31]) ?
                                         {31'b0, f_a[31]} :
                                         {31'b0, difference[32]};

                ALU_SLTU: reference_alu = {31'b0, difference[32]};

                ALU_XOR: reference_alu = f_a ^ f_b;
                ALU_OR:  reference_alu = f_a | f_b;
                ALU_AND: reference_alu = f_a & f_b;

                ALU_MUL, ALU_MULH, ALU_MULHSU, ALU_MULHU: begin
                    if (f_op == ALU_MULH || f_op == ALU_MULHSU)
                        wide_a = {{32{f_a[31]}}, f_a};
                    if (f_op == ALU_MULH)
                        wide_b = {{32{f_b[31]}}, f_b};

                    product = wide_a * wide_b;

                    reference_alu = (f_op == ALU_MUL) ? product[31:0] :
                                                       product[63:32];
                end

                default: reference_alu = 32'h00000000;
            endcase
        end
    endfunction


    // Gerador xorshift32: sequência fixa para a semente dada, então
    // qualquer falha pode ser reproduzida.
    function [31:0] next_random;
        input [31:0] f_state;

        reg [31:0] x;

        begin
            x = f_state;
            x = x ^ (x << 13);
            x = x ^ (x >> 17);
            x = x ^ (x << 5);
            next_random = x;
        end
    endfunction


    // Mistura valores de borda com valores aleatórios.
    function [31:0] operand_value;
        input [2:0]  f_selector;
        input [31:0] f_random;

        begin
            case (f_selector)
                3'd0:    operand_value = 32'h00000000;
                3'd1:    operand_value = 32'hFFFFFFFF;
                3'd2:    operand_value = 32'h80000000;
                3'd3:    operand_value = 32'h7FFFFFFF;
                default: operand_value = f_random;
            endcase
        end
    endfunction


    // ------------------------------------------------------------
    // Geração do arquivo VCD.
    //
    // Pode ser aberto posteriormente no GTKWave.
    // ------------------------------------------------------------

    initial begin

        $dumpfile("target/wave.vcd");
        $dumpvars(0, arithmetic_logic_unit_tb);

    end


    // ------------------------------------------------------------
    // Testes.
    // ------------------------------------------------------------

    initial begin

        // Valores iniciais.
        operand_a = 32'h00000000;
        operand_b = 32'h00000000;
        op        = 5'd0;

        tests  = 0;
        passed = 0;
        failed = 0;


        // ========================================================
        // ADD
        // ========================================================

        check(
            ALU_ADD,
            32'd10,
            32'd20,
            32'd30
        );

        check(
            ALU_ADD,
            32'hFFFFFFFF,
            32'd1,
            32'h00000000
        );


        // ========================================================
        // SUB
        // ========================================================

        check(
            ALU_SUB,
            32'd20,
            32'd10,
            32'd10
        );

        check(
            ALU_SUB,
            32'd10,
            32'd20,
            32'hFFFFFFF6
        );


        // ========================================================
        // SLL
        //
        // 1 << 4 = 16
        // ========================================================

        check(
            ALU_SLL,
            32'h00000001,
            32'd4,
            32'h00000010
        );


        // ========================================================
        // SLT
        //
        // Comparação com sinal.
        //
        // -1 < 1
        // ========================================================

        check(
            ALU_SLT,
            32'hFFFFFFFF,
            32'h00000001,
            32'h00000001
        );


        // 5 < 2 é falso.

        check(
            ALU_SLT,
            32'd5,
            32'd2,
            32'h00000000
        );


        // ========================================================
        // SLTU
        //
        // Comparação sem sinal.
        //
        // 0xFFFFFFFF é 4294967295 quando interpretado como unsigned.
        //
        // Portanto:
        //
        // 0xFFFFFFFF < 1 é falso.
        // ========================================================

        check(
            ALU_SLTU,
            32'hFFFFFFFF,
            32'h00000001,
            32'h00000000
        );


        check(
            ALU_SLTU,
            32'd1,
            32'd2,
            32'h00000001
        );


        // ========================================================
        // XOR
        // ========================================================

        check(
            ALU_XOR,
            32'hAAAAAAAA,
            32'h55555555,
            32'hFFFFFFFF
        );


        // ========================================================
        // SRL
        //
        // Shift lógico:
        //
        // zeros entram pela esquerda.
        // ========================================================

        check(
            ALU_SRL,
            32'h80000000,
            32'd1,
            32'h40000000
        );


        // ========================================================
        // SRA
        //
        // Shift aritmético.
        //
        // 0x80000000 é negativo em complemento de dois.
        //
        // O bit de sinal deve ser preservado.
        // ========================================================

        check(
            ALU_SRA,
            32'h80000000,
            32'd1,
            32'hC0000000
        );


        check(
            ALU_SRA,
            32'hFFFFFFF0,
            32'd2,
            32'hFFFFFFFC
        );


        // ========================================================
        // OR
        // ========================================================

        check(
            ALU_OR,
            32'hF0F00000,
            32'h0F0F0000,
            32'hFFFF0000
        );


        // ========================================================
        // AND
        // ========================================================

        check(
            ALU_AND,
            32'hF0F0F0F0,
            32'h0FF00FF0,
            32'h00F000F0
        );


        // ========================================================
        // MUL
        //
        // Retorna os 32 bits inferiores.
        //
        // 10 * 20 = 200 = 0xC8
        // ========================================================

        check(
            ALU_MUL,
            32'd10,
            32'd20,
            32'd200
        );


        // Teste com valores negativos:
        //
        // -2 * 3 = -6
        //
        // -6 em complemento de dois:
        //
        // 0xFFFFFFFA
        // ========================================================

        check(
            ALU_MUL,
            32'hFFFFFFFE,
            32'd3,
            32'hFFFFFFFA
        );


        // ========================================================
        // MULH
        //
        // signed * signed
        //
        // -2 * 3 = -6
        //
        // Em 64 bits:
        //
        // FFFFFFFFFFFFFFFA
        //
        // Parte superior:
        //
        // FFFFFFFF
        // ========================================================

        check(
            ALU_MULH,
            32'hFFFFFFFE,
            32'd3,
            32'hFFFFFFFF
        );


        // ========================================================
        // MULHU
        //
        // unsigned * unsigned
        //
        // 0xFFFFFFFF * 0xFFFFFFFF
        //
        // =
        //
        // FFFFFFFE00000001
        //
        // Parte superior:
        //
        // FFFFFFFE
        // ========================================================

        check(
            ALU_MULHU,
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hFFFFFFFE
        );


        // ========================================================
        // MULHSU
        //
        // signed * unsigned
        //
        // operand_a = -2
        // operand_b = 3
        //
        // resultado completo = -6
        //
        // Parte superior = FFFFFFFF
        // ========================================================

        check(
            ALU_MULHSU,
            32'hFFFFFFFE,
            32'd3,
            32'hFFFFFFFF
        );


        // ========================================================
        // Operação inválida.
        //
        // Pela implementação atual, deve retornar zero.
        // ========================================================

        check(
            5'd31,
            32'h12345678,
            32'h87654321,
            32'h00000000
        );


        // ========================================================
        // Casos de borda.
        // ========================================================

        // Shifts por 0 e 31; só os 5 bits menos significativos
        // de operand_b contam (32 desloca 0, 0xFFFFFFE1 desloca 1).
        check(ALU_SLL, 32'h12345678, 32'd0,         32'h12345678);
        check(ALU_SLL, 32'h00000001, 32'd31,        32'h80000000);
        check(ALU_SLL, 32'h00000001, 32'd32,        32'h00000001);
        check(ALU_SLL, 32'h00000001, 32'hFFFFFFE1,  32'h00000002);
        check(ALU_SRL, 32'h80000000, 32'd0,         32'h80000000);
        check(ALU_SRL, 32'h80000000, 32'd31,        32'h00000001);
        check(ALU_SRA, 32'h80000000, 32'd31,        32'hFFFFFFFF);
        check(ALU_SRA, 32'h7FFFFFFF, 32'd31,        32'h00000000);
        check(ALU_SRA, 32'h80000000, 32'd33,        32'hC0000000);

        // Comparações nos extremos e com operandos iguais.
        check(ALU_SLT,  32'h80000000, 32'h7FFFFFFF, 32'h00000001);
        check(ALU_SLT,  32'h7FFFFFFF, 32'h80000000, 32'h00000000);
        check(ALU_SLT,  32'd5,        32'd5,        32'h00000000);
        check(ALU_SLTU, 32'h00000000, 32'hFFFFFFFF, 32'h00000001);
        check(ALU_SLTU, 32'hFFFFFFFF, 32'h00000000, 32'h00000000);
        check(ALU_SLTU, 32'd5,        32'd5,        32'h00000000);

        // Overflow é modular: nenhuma exceção no RV32I.
        check(ALU_ADD, 32'h7FFFFFFF, 32'd1, 32'h80000000);
        check(ALU_SUB, 32'h00000000, 32'd1, 32'hFFFFFFFF);
        check(ALU_SUB, 32'h80000000, 32'd1, 32'h7FFFFFFF);

        // Multiplicação. MULH(FFFFFFFF, 1) e MULHU(FFFFFFFF, 1)
        // separam o tratamento signed do unsigned.
        check(ALU_MUL,    32'hFFFFFFFF, 32'hFFFFFFFF, 32'h00000001);
        check(ALU_MUL,    32'h80000000, 32'h80000000, 32'h00000000);
        check(ALU_MULH,   32'hFFFFFFFF, 32'h00000001, 32'hFFFFFFFF);
        check(ALU_MULH,   32'h80000000, 32'h80000000, 32'h40000000);
        check(ALU_MULH,   32'hFFFFFFFF, 32'hFFFFFFFF, 32'h00000000);
        check(ALU_MULH,   32'h7FFFFFFF, 32'h7FFFFFFF, 32'h3FFFFFFF);
        check(ALU_MULHSU, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF);
        check(ALU_MULHSU, 32'h7FFFFFFF, 32'hFFFFFFFF, 32'h7FFFFFFE);
        check(ALU_MULHSU, 32'h80000000, 32'hFFFFFFFF, 32'h80000000);
        check(ALU_MULHU,  32'h80000000, 32'd2,        32'h00000001);
        check(ALU_MULHU,  32'hFFFFFFFF, 32'h00000001, 32'h00000000);

        // Todos os códigos sem operação devolvem zero.
        for (iteration = 14; iteration < 32; iteration = iteration + 1)
            check(iteration[4:0], 32'h12345678, 32'h9ABCDEF0, 32'h00000000);


        // ========================================================
        // Teste aleatório contra o modelo de referência.
        //
        // Sem waveform durante o laço, para o VCD não crescer.
        // ========================================================

        $dumpoff;
        random_state = 32'h2545F491;

        for (iteration = 0; iteration < RANDOM_ITERATIONS; iteration = iteration + 1) begin

            random_state = next_random(random_state);
            op = random_state % 14;

            random_state = next_random(random_state);
            selector = random_state[2:0];
            random_state = next_random(random_state);
            operand_a = operand_value(selector, random_state);

            random_state = next_random(random_state);
            selector = random_state[2:0];
            random_state = next_random(random_state);
            operand_b = operand_value(selector, random_state);

            #1;

            expected = reference_alu(op, operand_a, operand_b);
            tests = tests + 1;

            if (result === expected) begin
                passed = passed + 1;
            end else begin
                failed = failed + 1;
                if (failed <= 10)
                    $display(
                        "FALHOU (aleatorio) | op=%0d | a=%h | b=%h | esperado=%h | recebido=%h",
                        op, operand_a, operand_b, expected, result
                    );
            end

        end

        $dumpon;


        // ========================================================
        // Resultado final.
        // ========================================================

        $display("");
        $display("--------------------------------------------");
        $display("Resultado dos testes");
        $display("--------------------------------------------");

        $display("Total:   %0d", tests);
        $display("Passou:  %0d", passed);
        $display("Falhou:  %0d", failed);

        $display("--------------------------------------------");


        // Pequeno atraso apenas para deixar o waveform mais
        // confortável de visualizar no GTKWave.
        #5;

        if (failed != 0)
            $fatal(1, "EXISTEM TESTES COM ERRO: %0d de %0d falharam.", failed, tests);

        $display("PASS arithmetic_logic_unit");
        $finish;

    end

endmodule