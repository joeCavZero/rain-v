/* Subsystem de dados RV32I 4-wide: 4 LSUs -> 4:4 -> RAM multiportas.
 * Interfaces dirigidas por vetores por lane. Base/offset JA somados pela ALU.
 * Para cada lane: funct3 em [lane*3 +:3], store_data e address em 32 bits.
 * Portas de leitura combinacionais, stores com commit na borda de subida.
 * Store->load no mesmo ciclo e na mesma palavra usa bypass com ordem de lane.
 *
 * 'memory_valid' marca acessos legais e dentro da RAM (prontos).
 * 'load_valid' marca resultados de load prontos.
 * Excecoes: misaligned, illegal_op e out_of_range DEVEM inibir commit no
 * controlador externo; nao ha mecanismo de trap neste modulo isolado.
 * lane_valid deve ser a mascara efetivamente emitida, nunca apenas decode.
 */
module memory_subsystem_4wide #(
    parameter WORDS = 256
) (
    input  wire         clk,
    input  wire [3:0]   lane_valid,
    input  wire [3:0]   mem_read,
    input  wire [3:0]   mem_write,
    input  wire [127:0] effective_address,
    input  wire [127:0] store_data,
    input  wire [11:0]  funct3,
    output wire [127:0] load_result,
    output wire [3:0]   request_grant,
    output wire [3:0]   memory_valid,
    output wire [3:0]   load_valid,
    output wire [3:0]   misaligned,
    output wire [3:0]   illegal_op,
    output wire [3:0]   out_of_range
);
    wire [127:0] aligned_address,shifted_stores,raw_words,formatted_load;
    wire [15:0] masks;
    wire [3:0] access_valid,address_valid,requests,stores,raw_requests;
    wire [3:0] lane_fault;
    reg  [3:0] safe_prefix;
    reg  older_fault;
    integer idx;
    wire [3:0] stalled_requests,issue_allow_mask;
    wire [3:0] ram_valid,ram_write;
    wire [127:0] ram_address,ram_write_data;
    wire [15:0] ram_mask;

    genvar lane;
    generate for(lane=0;lane<4;lane=lane+1) begin: LANE
        load_store_unit lsu (
            .address(effective_address[lane*32 +:32]),
            .store_data(store_data[lane*32 +:32]),
            .raw_word(raw_words[lane*32 +:32]),
            .funct3(funct3[lane*3 +:3]),
            .mem_read(mem_read[lane] & lane_valid[lane]),
            .mem_write(mem_write[lane] & lane_valid[lane]),
            .aligned_address(aligned_address[lane*32 +:32]),
            .store_word(shifted_stores[lane*32 +:32]),
            .store_mask(masks[lane*4 +:4]),
            .load_result(formatted_load[lane*32 +:32]),
            .access_valid(access_valid[lane]),
            .misaligned(misaligned[lane]),
            .illegal_op(illegal_op[lane])
        );
        assign load_result[lane*32 +:32] = load_valid[lane] ?
            formatted_load[lane*32 +:32] : 32'b0;
    end endgenerate
    assign raw_requests = access_valid & lane_valid;
    // Para excecoes precisas: um acesso com erro interrompe o grupo.
    // Nenhuma lane mais jovem pode escrever na memoria na mesma borda.
    // 'address_valid' depende apenas de ram_address (nao de ram_valid).
    assign lane_fault = (lane_valid & (misaligned | illegal_op)) |
                        (raw_requests & ~address_valid);
    always @(*) begin
        safe_prefix = 4'b1111;
        older_fault = 1'b0;
        for (idx=0; idx<4; idx=idx+1) begin
            if (older_fault)
                safe_prefix[idx] = 1'b0;
            if (lane_fault[idx])
                older_fault = 1'b1;
        end
    end
    assign requests = raw_requests & safe_prefix;
    assign stores = requests & mem_write;

    memory_arbiter arbiter (
        .request_valid(requests), .request_write(stores),
        .request_address(aligned_address), .request_write_data(shifted_stores),
        .request_byte_enable(masks), .grant(request_grant),
        .stalled_requests(stalled_requests),
        .issue_allow_mask(issue_allow_mask), .memory_valid(ram_valid),
        .memory_write(ram_write), .memory_address(ram_address),
        .memory_write_data(ram_write_data), .memory_byte_enable(ram_mask)
    );

    memory_4wide #(.WORDS(WORDS)) ram (
        .clk(clk), .request_valid(ram_valid), .write_enable(ram_write),
        .address(ram_address), .write_data(ram_write_data),
        .byte_enable(ram_mask), .read_data(raw_words),
        .address_valid(address_valid)
    );
    assign memory_valid = request_grant & address_valid;
    assign load_valid = memory_valid & mem_read;
    assign out_of_range = raw_requests & ~address_valid;
endmodule
