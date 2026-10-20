/* RAM RV32I de dados com QUATRO portas de acesso real por ciclo.
 * Lane 0 = instrucao mais antiga; lane 3 = mais jovem.
 * Entradas agrupadas por lane, lane i na fatia [i*WIDTH +: WIDTH].
 * Enderecos sao de BYTE, mas DEVEM estar alinhados a 4: LSU trata formatos.
 * 4 loads, 4 stores ou qualquer combinacao sao aceitos no mesmo ciclo,
 * inclusive se todos apontam para a mesma palavra.
 *
 * Semantica de conflito em ordem de programa dentro do grupo:
 * - Um load ve todas as stores MAIS ANTIGAS do mesmo ciclo (bypass).
 * - Um load NAO ve as stores mais jovens.
 * - Duas stores para o mesmo byte: vence a lane mais jovem.
 * - Stores de bytes diferentes na mesma palavra sao combinadas.
 * - Endereco invalido: leitura zero, nenhuma escrita, address_valid=0.
 *
 * Memoria assincrona na leitura / sincrona na escrita, SEM reset.
 * Implementacao multiportas comportamental: sintetizavel em flip-flops,
 * mas a area/timing devem ser validados para o fluxo fisico LibreLane.
 * Nao eh uma inferencia garantida de SRAM 4R/4W.
 */
module memory_4wide #(
    parameter WORDS = 256
) (
    input  wire         clk,
    input  wire [3:0]   request_valid,
    input  wire [3:0]   write_enable,
    input  wire [127:0] address,
    input  wire [127:0] write_data,
    input  wire [15:0]  byte_enable,
    output reg  [127:0] read_data,
    output wire [3:0]   address_valid
);
    reg [31:0] mem [0:WORDS-1];
    genvar lane;
    generate
        for (lane=0; lane<4; lane=lane+1) begin: ADDRESS_CHECK
            assign address_valid[lane] =
                (address[lane*32 +: 2] == 2'b00) &&
                (address[lane*32+2 +: 30] < WORDS);
        end
    endgenerate

    integer r,older,byte_no;
    reg [31:0] read_word;
    always @(*) begin
        read_data = 128'b0;
        read_word = 32'b0;
        for (r=0; r<4; r=r+1) begin
            if (request_valid[r] && address_valid[r]) begin
                read_word = mem[address[r*32+2 +: 30]];
                // Forwarding de stores anteriores (ordem crescente de lanes).
                for (older=0; older<r; older=older+1) begin
                    if (request_valid[older] && write_enable[older] &&
                        address_valid[older] &&
                        (address[older*32 +: 32] == address[r*32 +: 32])) begin
                        for (byte_no=0; byte_no<4; byte_no=byte_no+1) begin
                            if (byte_enable[older*4+byte_no])
                                read_word[byte_no*8 +: 8] =
                                    write_data[older*32+byte_no*8 +: 8];
                        end
                    end
                end
                read_data[r*32 +: 32] = read_word;
            end else begin
                read_word = 32'b0;
            end
        end
    end

    integer w,b;
    always @(posedge clk) begin
        for (w=0; w<4; w=w+1) begin
            if (request_valid[w] && write_enable[w] && address_valid[w]) begin
                for (b=0; b<4; b=b+1) begin
                    if (byte_enable[w*4+b])
                        mem[address[w*32+2 +: 30]][b*8 +: 8] <=
                            write_data[w*32+b*8 +: 8];
                end
            end
        end
    end
endmodule
