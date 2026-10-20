/* Selecao de resultados RV32I para quatro portas de escrita.
 * Consistente com instruction_decoder.v:
 *   wb_sel = 0 -> resultado ALU; 1 -> resultado LOAD;
 *            2 -> PC+4 (JAL/JALR); 3 -> imediato U (LUI).
 * valid_in representa resultados efetivamente prontos/aceitos para commit.
 * exception_mask barra writes de instrucoes invalidas/anuladas.
 * O banco de registradores aplica prioridade para lane mais nova em WAW.
 */
module writeback_unit (
    input  wire [3:0]   valid_in,
    input  wire [3:0]   reg_write_in,
    input  wire [3:0]   exception_mask,
    input  wire [19:0]  rd_in,
    input  wire [7:0]   wb_sel,
    input  wire [127:0] alu_result,
    input  wire [127:0] mem_result,
    input  wire [127:0] pc_plus4,
    input  wire [127:0] upper_immediate,
    output reg  [3:0]   write_enable,
    output wire [19:0]  write_addresses,
    output reg  [127:0] write_data
);
    integer i;
    assign write_addresses = rd_in;
    always @(*) begin
        write_enable = 4'b0;
        write_data=128'b0;
        for(i=0;i<4;i=i+1) begin
            case (wb_sel[i*2 +: 2])
                2'b00: write_data[i*32 +: 32]=alu_result[i*32 +: 32];
                2'b01: write_data[i*32 +: 32]=mem_result[i*32 +: 32];
                2'b10: write_data[i*32 +: 32]=pc_plus4[i*32 +: 32];
                2'b11: write_data[i*32 +: 32]=upper_immediate[i*32 +: 32];
                default: write_data[i*32 +: 32]=0;
            endcase
            if (valid_in[i] && reg_write_in[i] && !exception_mask[i]
                && rd_in[i*5 +: 5]!=5'd0)
                write_enable[i]=1;
        end
    end
endmodule
