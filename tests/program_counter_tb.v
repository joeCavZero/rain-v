/*
    Testbench do Program Counter.

    Este arquivo não representa hardware real.

    Ele serve apenas para:
        - gerar clock;
        - controlar o reset;
        - observar o valor do PC;
        - gerar o arquivo wave.vcd;
        - verificar se o Program Counter está funcionando corretamente.
*/

module program_counter_tb;

    /*
        Entradas que o testbench controla.
    */
    reg clk;
    reg reset;

    /*
        Saída produzida pelo Program Counter.
    */
    wire [31:0] value;


    /*
        Instancia o hardware que queremos testar.

        dut significa:
            Device Under Test

        Ou seja:
            dispositivo que está sendo testado.
    */
    program_counter dut (
        .clk   (clk),
        .reset (reset),
        .value (value)
    );


    /*
        Gera o arquivo utilizado pelo GTKWave.

        wave.vcd:
            contém as mudanças dos sinais durante a simulação.

        $dumpvars:
            informa quais sinais devem ser armazenados.
    */
    initial begin
        $dumpfile("target/wave.vcd");
        $dumpvars(0, program_counter_tb);
    end


    /*
        Gerador de clock.

        Inicialmente:
            clk = 0

        A cada 5 unidades de tempo:
            o clock é invertido.

        Portanto:

            0 -----
                  |
            1     -----
                      |
            0         -----

        O período completo do clock é 10 unidades de tempo.
    */
    initial begin
        clk = 0;

        forever #5 clk = ~clk;
    end


    /*
        Executa os testes.
    */
    initial begin

        /*
            Começamos com reset ativo.

            Assim garantimos que o PC comece em 0.
        */
        reset = 1;


        /*
            Esperamos duas bordas de subida do clock
            enquanto o reset continua ativo.
        */
        @(posedge clk);
        @(posedge clk);


        /*
            Desligamos o reset.

            Agora o PC poderá começar a incrementar.
        */
        reset = 0;


        /*
            Próxima borda de clock:

                PC deve passar de 0 para 4.
        */
        @(posedge clk);
        #1;

        $display("value = %d", value);

        if (value !== 32'd4) begin
            $error("Erro: esperado 4, recebido %d", value);
        end


        /*
            Próxima borda:

                PC deve passar de 4 para 8.
        */
        @(posedge clk);
        #1;

        $display("value = %d", value);

        if (value !== 32'd8) begin
            $error("Erro: esperado 8, recebido %d", value);
        end


        /*
            Próxima borda:

                PC deve passar de 8 para 12.
        */
        @(posedge clk);
        #1;

        $display("value = %d", value);

        if (value !== 32'd12) begin
            $error("Erro: esperado 12, recebido %d", value);
        end


        /*
            Próxima borda:

                PC deve passar de 12 para 16.
        */
        @(posedge clk);
        #1;

        $display("value = %d", value);

        if (value !== 32'd16) begin
            $error("Erro: esperado 16, recebido %d", value);
        end


        /*
            Se chegamos até aqui sem nenhum $error,
            o comportamento básico do PC está correto.
        */
        $display("Program Counter testado com sucesso.");

        $finish;
    end

endmodule