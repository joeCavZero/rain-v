/* Decoder RV32I: sem C, CSR, FENCE, ECALL/EBREAK ou excecoes.
   op usa codigos da ALU existente: ADD=0 SUB=1 SLL=2 SLT=3 SLTU=4
   XOR=5 SRL=6 SRA=7 OR=8 AND=9 MUL=10..13 (M parcial).
   wb_sel: 0=ALU, 1=MEM, 2=PC+4, 3=imediato U (LUI).
   branch_type: 0=nenhum, 1=BEQ, 2=BNE, 3=BLT, 4=BGE,
                5=BLTU, 6=BGEU, 7=JAL, 8=JALR.
*/
module instruction_decoder (
    input wire [31:0] instruction,
    output wire [4:0] rs1, rs2, rd,
    output reg uses_rs1, uses_rs2, reg_write, mem_read, mem_write,
    output reg alu_src_imm, illegal,
    output reg [4:0] alu_op,
    output reg [1:0] wb_sel,
    output reg [3:0] branch_type,
    output wire [31:0] immediate
);
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd = instruction[11:7];
    immediate_generator imm_gen(.instruction(instruction),.immediate(immediate));
    always @(*) begin
        uses_rs1=0; uses_rs2=0; reg_write=0; mem_read=0; mem_write=0;
        alu_src_imm=0; illegal=0; alu_op=0; wb_sel=0; branch_type=0;
        case (opcode)
            7'b0110011: begin // OP
                uses_rs1=1; uses_rs2=1; reg_write=1;
                if (funct7==7'b0000001) begin
                    case (funct3)
                        3'b000: alu_op=10;
                        3'b001: alu_op=11;
                        3'b010: alu_op=12;
                        3'b011: alu_op=13;
                        default: illegal=1;
                    endcase
                end else begin
                    case (funct3)
                        3'b000: begin if(funct7==7'b0100000) alu_op=1; else if(funct7!=0) illegal=1; end
                        3'b001: begin alu_op=2; if(funct7!=0) illegal=1; end
                        3'b010: begin alu_op=3; if(funct7!=0) illegal=1; end
                        3'b011: begin alu_op=4; if(funct7!=0) illegal=1; end
                        3'b100: begin alu_op=5; if(funct7!=0) illegal=1; end
                        3'b101: begin if(funct7==7'b0100000) alu_op=7; else if(funct7==0) alu_op=6; else illegal=1; end
                        3'b110: begin alu_op=8; if(funct7!=0) illegal=1; end
                        3'b111: begin alu_op=9; if(funct7!=0) illegal=1; end
                    endcase
                end
            end
            7'b0010011: begin // OP-IMM
                uses_rs1=1; reg_write=1; alu_src_imm=1;
                case(funct3)
                    3'b000: alu_op=0;
                    3'b010: alu_op=3;
                    3'b011: alu_op=4;
                    3'b100: alu_op=5;
                    3'b110: alu_op=8;
                    3'b111: alu_op=9;
                    3'b001: begin alu_op=2; if(funct7!=0) illegal=1; end
                    3'b101: begin if(funct7==0) alu_op=6; else if(funct7==7'b0100000) alu_op=7; else illegal=1; end
                endcase
            end
            7'b0000011: begin // LOAD
                uses_rs1=1; reg_write=1; mem_read=1; alu_src_imm=1; wb_sel=1;
                if(!(funct3==0 || funct3==1 || funct3==2 || funct3==4 || funct3==5)) illegal=1;
            end
            7'b0100011: begin // STORE
                uses_rs1=1; uses_rs2=1; mem_write=1; alu_src_imm=1;
                if(!(funct3==0 || funct3==1 || funct3==2)) illegal=1;
            end
            7'b1100011: begin // BRANCH
                uses_rs1=1; uses_rs2=1;
                case(funct3)
                    3'b000: branch_type=1;
                    3'b001: branch_type=2;
                    3'b100: branch_type=3;
                    3'b101: branch_type=4;
                    3'b110: branch_type=5;
                    3'b111: branch_type=6;
                    default: illegal=1;
                endcase
            end
            7'b1101111: begin reg_write=1; wb_sel=2; branch_type=7; end // JAL
            7'b1100111: begin // JALR
                uses_rs1=1; reg_write=1; wb_sel=2; branch_type=8;
                if(funct3!=0) illegal=1;
            end
            7'b0110111: begin reg_write=1; wb_sel=3; end // LUI
            7'b0010111: begin reg_write=1; wb_sel=0; alu_src_imm=1; end // AUIPC: ALU recebe PC como operando A
            default: illegal=1;
        endcase
        if (illegal) begin
            uses_rs1=0; uses_rs2=0; reg_write=0; mem_read=0; mem_write=0;
            alu_src_imm=0; alu_op=0; wb_sel=0; branch_type=0;
        end
    end
endmodule
