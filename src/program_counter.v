/*
    Program Counter de 32 bits.

    O PC guarda o endereço da instrução atual.

    A cada borda de subida do clock:
        - Se reset estiver ativo:
            pc = 0
        - Senão:
            pc = pc + 4

    Somamos 4 porque cada instrução RISC-V RV32 possui 4 bytes.
*/

module program_counter (
    input  wire        clk,   // clock do processador
    input  wire        reset, // coloca o PC de volta em 0

    output reg [31:0]   value  // valor atual do Program Counter
);

    /*
        Este bloco é executado a cada borda de subida do clock.

        posedge clk:
            significa "quando o clock muda de 0 para 1".
    */
    always @(posedge clk) begin

        /*
            Se reset estiver ativo:
                volta o PC para 0.

            Senão:
                avança para a próxima instrução.
        */
        if (reset) begin
            value <= 32'h00000000;
        end
        else begin
            value <= value + 32'd4;
        end

    end

endmodule