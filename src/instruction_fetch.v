/* ROM 4-wide de instrucoes, enderecada em bytes, leitura combinacional.
   INIT_FILE="" permite carregar via testbench ($readmemh na memoria hierarquica).
   Memoria inicializada com NOP para simular sem arquivo de programa.
   Implementacao didatica: 4 leituras simultaneas podem exigir replicacao de ROM em FPGA/ASIC.
*/
module instruction_fetch #(
    parameter WORDS=256,
    parameter INIT_FILE=""
) (
    input wire [31:0] pc,
    output reg [127:0] instructions,
    output reg [3:0] valid
);
    reg [31:0] rom [0:WORDS-1];
    integer k;
    initial begin
        for(k=0;k<WORDS;k=k+1) rom[k]=32'h00000013; // addi x0,x0,0
        if(INIT_FILE!="") $readmemh(INIT_FILE,rom);
    end
    integer i;
    integer index_word;
    always @(*) begin
        instructions=128'b0; valid=4'b0;
        for(i=0;i<4;i=i+1) begin
            index_word=(pc>>2)+i;
            if((pc[1:0]==0) && (index_word<WORDS) && (index_word>=0)) begin
                instructions[i*32 +: 32]=rom[index_word];
                valid[i]=1'b1;
            end
        end
    end
endmodule
