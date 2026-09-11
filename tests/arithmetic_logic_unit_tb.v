`timescale 1ns/1ps

module arithmetic_logical_unit_tb;

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
    // Devem ser iguais aos definidos em arithmetic_logical_unit.v.
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

    arithmetic_logical_unit dut (
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
    // Geração do arquivo VCD.
    //
    // Pode ser aberto posteriormente no GTKWave.
    // ------------------------------------------------------------

    initial begin

        $dumpfile("target/wave.vcd");
        $dumpvars(0, arithmetic_logical_unit_tb);

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


        if (failed == 0)
            $display("TODOS OS TESTES PASSARAM.");
        else
            $display("EXISTEM TESTES COM ERRO.");


        // Pequeno atraso apenas para deixar o waveform mais
        // confortável de visualizar no GTKWave.
        #5;

        $finish;

    end

endmodule