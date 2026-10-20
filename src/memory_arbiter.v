/* Distribuidor 4->4 de requisicoes para RAM verdadeiramente multiportas.
 * Nao ha disputa por porta: as quatro lanes podem ser aceitas juntas,
 * mesmo que leiam/escrevam a mesma palavra. Conflitos de dados sao
 * resolvidos na memory_4wide, obedecendo a idade das instrucoes.
 *
 * A Issue Unit de Dielson continua responsavel pelo prefixo in-order
 * e hazards entre registradores; nao use 'grant' para ignorar RAW/branch.
 * Requisicoes invalidas (misalign/illegal) devem ser filtradas na LSU.
 * Enderecos fora da capacidade sao sinalizados por memory_4wide.address_valid.
 */
module memory_arbiter (
    input  wire [3:0]   request_valid,
    input  wire [3:0]   request_write,
    input  wire [127:0] request_address,
    input  wire [127:0] request_write_data,
    input  wire [15:0]  request_byte_enable,
    output wire [3:0]   grant,
    output wire [3:0]   stalled_requests,
    output wire [3:0]   issue_allow_mask,
    output wire [3:0]   memory_valid,
    output wire [3:0]   memory_write,
    output wire [127:0] memory_address,
    output wire [127:0] memory_write_data,
    output wire [15:0]  memory_byte_enable
);
    assign grant = request_valid;
    assign stalled_requests = 4'b0000;
    assign issue_allow_mask = 4'b1111;
    assign memory_valid = request_valid;
    assign memory_write = request_valid & request_write;
    assign memory_address = request_address;
    assign memory_write_data = request_write_data;
    assign memory_byte_enable = request_byte_enable;
endmodule
