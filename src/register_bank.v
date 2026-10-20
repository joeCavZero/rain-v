/* Banco RV32I 4-wide.
 * Lane 0 e a instrucao mais antiga; lane 3 a mais nova.
 * read_addresses: [4:0] = porta 0 ... [39:35] = porta 7.
 * write_addresses / write_data: lane i ocupa a fatia i*LARGURA +: LARGURA.
 * Leitura combinacional, escrita e reset sincronos na borda de subida.
 * Em conflitos WAW no mesmo ciclo, a lane mais nova vence.
 * Nao faz forwarding: RAW entre estagios pertence ao modulo de forwarding.
 */
module register_bank (
    input  wire         clk,
    input  wire         reset,
    input  wire [39:0]  read_addresses,
    output reg  [255:0] read_data,
    input  wire [3:0]   write_enable,
    input  wire [19:0]  write_addresses,
    input  wire [127:0] write_data
);
    reg [31:0] registers [0:31];
    integer r;
    integer w;
    reg [4:0] selected_read;

    always @(*) begin
        read_data = 256'b0;
        selected_read = 5'b0;
        for (r = 0; r < 8; r = r + 1) begin
            selected_read = read_addresses[r*5 +: 5];
            if (selected_read != 5'd0)
                read_data[r*32 +: 32] = registers[selected_read];
        end
    end

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end else begin
            // Ordem crescente: uma escrita da lane mais nova prevalece.
            for (w = 0; w < 4; w = w + 1) begin
                if (write_enable[w] && (write_addresses[w*5 +: 5] != 5'd0))
                    registers[write_addresses[w*5 +: 5]] <= write_data[w*32 +: 32];
            end
        end
    end
endmodule
