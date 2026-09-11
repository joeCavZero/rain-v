module arithmetic_logical_unit (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [4:0]  op,

    output reg  [31:0] result
);

    // ------------------------------------------------------------
    // Códigos das operações da ALU.
    //
    // O decoder será responsável por transformar opcode/funct3/
    // funct7 nesses códigos.
    // ------------------------------------------------------------

    localparam ALU_ADD    = 5'd0;
    localparam ALU_SUB    = 5'd1;

    localparam ALU_SLL    = 5'd2;
    localparam ALU_SLT    = 5'd3;
    localparam ALU_SLTU   = 5'd4;

    localparam ALU_XOR    = 5'd5;
    localparam ALU_SRL    = 5'd6;
    localparam ALU_SRA    = 5'd7;

    localparam ALU_OR     = 5'd8;
    localparam ALU_AND    = 5'd9;

    // ------------------------------------------------------------
    // Operações da extensão M.
    // ------------------------------------------------------------

    localparam ALU_MUL    = 5'd10;
    localparam ALU_MULH   = 5'd11;
    localparam ALU_MULHSU = 5'd12;
    localparam ALU_MULHU  = 5'd13;


    // ------------------------------------------------------------
    // Valores auxiliares de 64 bits usados nas multiplicações.
    //
    // signed * signed
    //
    // signed * unsigned
    //
    // unsigned * unsigned
    // ------------------------------------------------------------

    reg signed [63:0] mul_signed;
    reg signed [63:0] mul_signed_unsigned;
    reg        [63:0] mul_unsigned;


    // ------------------------------------------------------------
    // ALU combinacional.
    //
    // Não existe clock aqui.
    //
    // Sempre que operand_a, operand_b ou alu_op mudarem,
    // o resultado é recalculado.
    // ------------------------------------------------------------

    always @(*) begin

        // Valor padrão.
        //
        // Evita inferência de latch caso alguma operação não seja
        // reconhecida.
        result = 32'h00000000;


        // --------------------------------------------------------
        // Calcula previamente os produtos de 64 bits.
        //
        // Eles serão usados pelas instruções MUL/MULH/MULHSU/MULHU.
        // --------------------------------------------------------

        mul_signed =
            $signed(operand_a) *
            $signed(operand_b);

        mul_signed_unsigned =
            $signed(operand_a) *
            $signed({1'b0, operand_b});

        mul_unsigned =
            operand_a *
            operand_b;


        // --------------------------------------------------------
        // Seleção da operação.
        // --------------------------------------------------------

        case (op)

            // ----------------------------------------------------
            // ADD
            //
            // result = operand_a + operand_b
            //
            // Usado por:
            //
            // add
            // addi
            // lw/sw para cálculo de endereço
            // jal/jalr em partes do datapath
            // ----------------------------------------------------

            ALU_ADD: begin
                result = operand_a + operand_b;
            end


            // ----------------------------------------------------
            // SUB
            //
            // result = operand_a - operand_b
            // ----------------------------------------------------

            ALU_SUB: begin
                result = operand_a - operand_b;
            end


            // ----------------------------------------------------
            // SLL
            //
            // Shift lógico para esquerda.
            //
            // RISC-V usa somente os 5 bits menos significativos
            // para determinar o deslocamento em RV32.
            // ----------------------------------------------------

            ALU_SLL: begin
                result = operand_a << operand_b[4:0];
            end


            // ----------------------------------------------------
            // SLT
            //
            // Set Less Than com sinal.
            //
            // result = 1 se operand_a < operand_b
            // result = 0 caso contrário
            // ----------------------------------------------------

            ALU_SLT: begin

                if ($signed(operand_a) < $signed(operand_b))
                    result = 32'h00000001;
                else
                    result = 32'h00000000;

            end


            // ----------------------------------------------------
            // SLTU
            //
            // Set Less Than sem sinal.
            // ----------------------------------------------------

            ALU_SLTU: begin

                if (operand_a < operand_b)
                    result = 32'h00000001;
                else
                    result = 32'h00000000;

            end


            // ----------------------------------------------------
            // XOR
            // ----------------------------------------------------

            ALU_XOR: begin
                result = operand_a ^ operand_b;
            end


            // ----------------------------------------------------
            // SRL
            //
            // Shift lógico para direita.
            //
            // Como operand_a é unsigned, zeros entram pela esquerda.
            // ----------------------------------------------------

            ALU_SRL: begin
                result = operand_a >> operand_b[4:0];
            end


            // ----------------------------------------------------
            // SRA
            //
            // Shift aritmético para direita.
            //
            // Como usamos $signed, o bit de sinal é preservado.
            // ----------------------------------------------------

            ALU_SRA: begin
                result =
                    $signed(operand_a) >>> operand_b[4:0];
            end


            // ----------------------------------------------------
            // OR
            // ----------------------------------------------------

            ALU_OR: begin
                result = operand_a | operand_b;
            end


            // ----------------------------------------------------
            // AND
            // ----------------------------------------------------

            ALU_AND: begin
                result = operand_a & operand_b;
            end


            // ----------------------------------------------------
            // MUL
            //
            // Retorna os 32 bits menos significativos do produto.
            //
            // signed/unsigned não altera os bits inferiores do
            // resultado.
            // ----------------------------------------------------

            ALU_MUL: begin
                result = mul_unsigned[31:0];
            end


            // ----------------------------------------------------
            // MULH
            //
            // signed * signed
            //
            // Retorna os 32 bits superiores do produto de 64 bits.
            // ----------------------------------------------------

            ALU_MULH: begin
                result = mul_signed[63:32];
            end


            // ----------------------------------------------------
            // MULHSU
            //
            // signed * unsigned
            //
            // operand_a é interpretado como signed.
            // operand_b é interpretado como unsigned.
            // ----------------------------------------------------

            ALU_MULHSU: begin
                result = mul_signed_unsigned[63:32];
            end


            // ----------------------------------------------------
            // MULHU
            //
            // unsigned * unsigned
            //
            // Retorna os 32 bits superiores.
            // ----------------------------------------------------

            ALU_MULHU: begin
                result = mul_unsigned[63:32];
            end


            // ----------------------------------------------------
            // Operação inválida.
            // ----------------------------------------------------

            default: begin
                result = 32'h00000000;
            end

        endcase

    end

endmodule