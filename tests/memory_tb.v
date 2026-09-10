`timescale 1ns/1ps

module memory_tb;

    // ------------------------------------------------------------
    // Sinais conectados ao módulo memory
    // ------------------------------------------------------------

    reg         clk;
    reg  [31:0] address;
    reg  [31:0] write_data;
    reg         write_enable;

    wire [31:0] read_data;


    // ------------------------------------------------------------
    // Instância da memória
    // ------------------------------------------------------------

    memory dut (
        .clk(clk),
        .address(address),
        .write_data(write_data),
        .write_enable(write_enable),
        .read_data(read_data)
    );


    // ------------------------------------------------------------
    // Geração do arquivo VCD para visualização no GTKWave
    // ------------------------------------------------------------

    initial begin
        $dumpfile("target/wave.vcd");
        $dumpvars(0, memory_tb);
    end


    // ------------------------------------------------------------
    // Clock
    //
    // O clock começa em 0 e troca de valor a cada 5 ns.
    //
    // Portanto:
    //
    //     período = 10 ns
    //
    // Bordas de subida:
    //
    //     5 ns, 15 ns, 25 ns, ...
    // ------------------------------------------------------------

    initial begin
        clk = 0;

        forever #5 clk = ~clk;
    end


    // ------------------------------------------------------------
    // Testes
    // ------------------------------------------------------------

    initial begin

        // Valores iniciais
        address      = 32'h00000000;
        write_data   = 32'h00000000;
        write_enable = 0;


        // --------------------------------------------------------
        // Carrega o conteúdo inicial da memória.
        //
        // Cada linha do arquivo representa uma word de 32 bits.
        //
        // Linha 0 -> mem[0] -> endereço 0x00000000
        // Linha 1 -> mem[1] -> endereço 0x00000004
        // Linha 2 -> mem[2] -> endereço 0x00000008
        // Linha 3 -> mem[3] -> endereço 0x0000000C
        // --------------------------------------------------------

        $readmemh("inputs/memory_input.txt", dut.mem);


        // Pequeno atraso para garantir que os valores estejam
        // disponíveis antes das leituras.
        #1;


        // --------------------------------------------------------
        // TESTE 1
        //
        // Leitura do endereço 0x00000000.
        // --------------------------------------------------------

        address = 32'h00000000;

        #1;

        $display(
            "address = %h | read_data = %h",
            address,
            read_data
        );


        // --------------------------------------------------------
        // TESTE 2
        //
        // Leitura do endereço 0x00000004.
        // --------------------------------------------------------

        address = 32'h00000004;

        #1;

        $display(
            "address = %h | read_data = %h",
            address,
            read_data
        );


        // --------------------------------------------------------
        // TESTE 3
        //
        // Leitura do endereço 0x00000008.
        // --------------------------------------------------------

        address = 32'h00000008;

        #1;

        $display(
            "address = %h | read_data = %h",
            address,
            read_data
        );


        // --------------------------------------------------------
        // TESTE 4
        //
        // Leitura do endereço 0x0000000C.
        // --------------------------------------------------------

        address = 32'h0000000C;

        #1;

        $display(
            "address = %h | read_data = %h",
            address,
            read_data
        );


        // --------------------------------------------------------
        // TESTE 5
        //
        // Escrita síncrona.
        //
        // Tentamos escrever DEADC0DE no endereço 0x00000010.
        //
        // Como a memória escreve somente na borda de subida do
        // clock, o valor só deve ser armazenado após @(posedge clk).
        // --------------------------------------------------------

        address      = 32'h00000010;
        write_data   = 32'hDEADC0DE;
        write_enable = 1;


        // Espera a próxima borda de subida do clock.
        @(posedge clk);


        // Pequeno atraso para permitir a atualização da memória.
        #1;


        // Desabilita escrita.
        write_enable = 0;


        // --------------------------------------------------------
        // Verifica o valor escrito.
        // --------------------------------------------------------

        if (read_data == 32'hDEADC0DE) begin

            $display(
                "PASSOU: escrita em 0x00000010 | valor = %h",
                read_data
            );

        end else begin

            $display(
                "FALHOU: escrita em 0x00000010 | esperado = DEADC0DE | recebido = %h",
                read_data
            );

        end


        // --------------------------------------------------------
        // TESTE 6
        //
        // Verifica se um valor carregado originalmente pelo arquivo
        // continua intacto após a escrita anterior.
        // --------------------------------------------------------

        address = 32'h00000000;

        #1;

        if (read_data == 32'h003100B3) begin

            $display(
                "PASSOU: valor original preservado | read_data = %h",
                read_data
            );

        end else begin

            $display(
                "FALHOU: valor original alterado | read_data = %h",
                read_data
            );

        end


        // --------------------------------------------------------
        // Fim da simulação
        // --------------------------------------------------------

        $display("Fim dos testes.");

        #10;

        $finish;

    end

endmodule
