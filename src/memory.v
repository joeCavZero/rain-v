module memory (
    input  wire        clk,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    input  wire        write_enable,

    output wire [31:0] read_data
);

    // 256 palavras de 32 bits = 1024 bytes
    reg [31:0] mem [0:255];

    // endereço é em bytes.
    // como cada word tem 4 bytes, usamos address[9:2]
    assign read_data = mem[address[9:2]];

    always @(posedge clk) begin
        if (write_enable) begin
            mem[address[9:2]] <= write_data;
        end
    end

endmodule