/* Memoria de DADOS destinada ao backend 4-wide.
 * Uma porta fisica; escrita byte-wise para suportar SB/SH/SW.
 * 'address' e o endereco da palavra ALINHADA gerado pela LSU.
 * 'byte_enable' bit i controla os bits (i*8+7):(i*8).
 * O arbiter libera uma unica lane por ciclo para esta porta.
 * O array 'mem' e independente do modulo legado 'memory': instancie
 * APENAS esta memoria no backend, evitando bancos desconectados.
 */
module memory_byte_enabled #(
    parameter WORDS = 256
) (
    input  wire        clk,
    input  wire        request_valid,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    input  wire [3:0]  byte_enable,
    input  wire        write_enable,
    output wire [31:0] read_data,
    output wire        address_valid
);
    reg [31:0] mem [0:WORDS-1];
    wire in_range = (address[1:0] == 2'b00) && (address[31:2] < WORDS);
    assign address_valid = in_range;
    assign read_data = (request_valid && in_range) ? mem[address[31:2]] : 32'b0;

    integer b;
    always @(posedge clk) begin
        if (request_valid && write_enable && in_range) begin
            for (b=0; b<4; b=b+1) begin
                if (byte_enable[b])
                    mem[address[31:2]][b*8 +: 8] <= write_data[b*8 +: 8];
            end
        end
    end
endmodule
