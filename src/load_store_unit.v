/* Formatacao RV32I de load/store por lane.
 * Endereco efetivo vem da ALU (base rs1 + immediate); funct3 vem
 * diretamente de instruction[14:12], ainda disponivel no front-end.
 * A RAM recebe aligned_address e store_word/store_mask; retorna raw_word.
 * Tratamento sincrono de excecoes/commit fica com o backend.
 * IMPORTANTE: acesso desalinhado e rejeitado (nao emulado).
 */
module load_store_unit (
    input  wire [31:0] address,
    input  wire [31:0] store_data,
    input  wire [31:0] raw_word,
    input  wire [2:0]  funct3,
    input  wire        mem_read,
    input  wire        mem_write,
    output reg  [31:0] aligned_address,
    output reg  [31:0] store_word,
    output reg  [3:0]  store_mask,
    output reg  [31:0] load_result,
    output reg         access_valid,
    output reg         misaligned,
    output reg         illegal_op
);
    reg [7:0] selected_byte;
    reg [15:0] selected_half;
    reg [31:0] shifted_word;
    reg format_ok;
    always @(*) begin
        aligned_address = {address[31:2],2'b00};
        store_word = 32'b0;
        store_mask = 4'b0000;
        load_result = 32'b0;
        access_valid = 1'b0;
        misaligned = 1'b0;
        illegal_op = 1'b0;
        format_ok = 1'b0;
        shifted_word = raw_word >> (address[1:0] * 8);
        selected_byte = shifted_word[7:0];
        selected_half = shifted_word[15:0];

        if (mem_read && mem_write) begin
            illegal_op = 1'b1;
        end else if (mem_read) begin
            case (funct3)
                3'b000: begin format_ok=1; load_result={{24{selected_byte[7]}},selected_byte}; end  // LB
                3'b001: begin format_ok=1; load_result={{16{selected_half[15]}},selected_half}; end // LH
                3'b010: begin format_ok=1; load_result=raw_word; end                            // LW
                3'b100: begin format_ok=1; load_result={24'b0,selected_byte}; end               // LBU
                3'b101: begin format_ok=1; load_result={16'b0,selected_half}; end               // LHU
                default: illegal_op=1;
            endcase
            if (format_ok) begin
                if ((funct3==3'b001 || funct3==3'b101) && address[0]) misaligned=1;
                if (funct3==3'b010 && (address[1:0]!=0)) misaligned=1;
            end
        end else if (mem_write) begin
            case (funct3)
                3'b000: begin // SB: apenas os 8 bits menos significativos
                    format_ok=1;
                    store_mask=4'b0001 << address[1:0];
                    store_word={24'b0, store_data[7:0]} << (address[1:0] * 8);
                end
                3'b001: begin // SH: apenas os 16 bits menos significativos
                    format_ok=1;
                    store_mask=4'b0011 << address[1:0];
                    store_word={16'b0, store_data[15:0]} << (address[1:0] * 8);
                end
                3'b010: begin // SW: palavra completa
                    format_ok=1;
                    store_mask=4'b1111;
                    store_word=store_data;
                end
                default: illegal_op=1;
            endcase
            if (format_ok) begin
                if (funct3==3'b001 && address[0]) misaligned=1;
                if (funct3==3'b010 && (address[1:0]!=0)) misaligned=1;
            end
        end
        access_valid = (mem_read || mem_write) && format_ok && !misaligned && !illegal_op;
        if (!access_valid) begin
            store_mask=4'b0;
            store_word=32'b0;
            load_result=32'b0;
        end
    end
endmodule
