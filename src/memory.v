/* Compatibilidade com a interface original do projeto.
 * 256 words por padrao (1 KiB); um acesso por ciclo.
 * Mantem o array 'mem' acessivel por testes existentes:
 *   $readmemh("inputs/memory_input.txt", dut.mem);
 * Sem aliasing: enderecos desalinhados ou fora da faixa nao escrevem
 * e devolvem zero em leitura. Conteudo inicial indefinido ate ser escrito.
 */
module memory #(
    parameter WORDS = 256
) (
    input  wire        clk,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    input  wire        write_enable,
    output wire [31:0] read_data
);
    reg [31:0] mem [0:WORDS-1];
    wire address_valid = (address[1:0] == 2'b00) && (address[31:2] < WORDS);
    assign read_data = address_valid ? mem[address[31:2]] : 32'b0;
    always @(posedge clk) begin
        if (write_enable && address_valid)
            mem[address[31:2]] <= write_data;
    end
endmodule

