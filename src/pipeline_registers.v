/* Buffer ordenado de ate quatro instrucoes.
   load recebe novo grupo apenas quando empty; consume_count retira prefixo emitido.
   stall impede consumo; flush invalida tudo; flush tem prioridade sobre stall.
   Mantem PC de cada instrucao; NAO e um pipeline completo de 5 estagios.
*/
module pipeline_registers (
    input wire clk, reset, flush, stall, load,
    input wire [2:0] consume_count,
    input wire [127:0] instructions_in, pc_in,
    input wire [3:0] valid_in,
    output reg [127:0] instructions_out, pc_out,
    output reg [3:0] valid_out,
    output wire empty
);
    assign empty = (valid_out==0);
    integer i;
    always @(posedge clk) begin
        if(reset || flush) begin
            instructions_out<=0; pc_out<=0; valid_out<=0;
        end else if(!stall) begin
            if(load && empty) begin
                instructions_out<=instructions_in;
                pc_out<=pc_in;
                valid_out<=valid_in;
            end else if(consume_count!=0) begin
                for(i=0;i<4;i=i+1) begin
                    if(i+consume_count<4) begin
                        instructions_out[i*32 +: 32] <= instructions_out[(i+consume_count)*32 +: 32];
                        pc_out[i*32 +: 32] <= pc_out[(i+consume_count)*32 +: 32];
                        valid_out[i] <= valid_out[i+consume_count];
                    end else begin
                        instructions_out[i*32 +: 32] <= 0;
                        pc_out[i*32 +: 32] <= 0;
                        valid_out[i] <= 0;
                    end
                end
            end
        end
    end
endmodule
