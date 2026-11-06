/* RAW e WAW entre as lanes do grupo de 4 decodificado do front-end.
 * RAW: a lane i le registrador que uma lane j < i (mais antiga) escreve.
 * WAW: lanes escrevem o mesmo rd (informativo: o banco resolve por ordem
 * do programa, mais nova vence). Stores/branches (reg_write=0) e escritas
 * em x0 nao geram dependencia. RAW in-group vira obstaculo: issue_unit
 * emite so o prefixo consecutivo anterior a lane bloqueada.
 * Formato: lane i em [i*5 +: 5], idem decoded_* do central_processing_unit.
 */
module dependency_checker (
    input  wire [3:0]  valid,     // slot do grupo preenchido (decoded_valid)
    input  wire [3:0]  uses_rs1, uses_rs2,
    input  wire [3:0]  reg_write,
    input  wire [19:0] rs1, rs2, rd,
    output wire [3:0]  raw_dependency, // lane i depende de alguma lane mais antiga
    output wire [3:0]  waw_dependency  // lane i e lane mais antiga escrevem o mesmo rd (informativo)
);
    reg [3:0] raw_bits;
    reg [3:0] waw_bits;
    integer l;
    integer j;

    always @(*) begin
        raw_bits = 4'b0;
        waw_bits = 4'b0;
        for (l = 0; l < 4; l = l + 1)
            for (j = 0; j < l; j = j + 1)
                if (valid[l] && valid[j] && reg_write[j] && (rd[j*5 +: 5] != 5'd0)) begin
                    if ((uses_rs1[l] && (rs1[l*5 +: 5] == rd[j*5 +: 5])) ||
                        (uses_rs2[l] && (rs2[l*5 +: 5] == rd[j*5 +: 5])))
                        raw_bits[l] = 1'b1;
                    if (reg_write[l] && (rd[l*5 +: 5] == rd[j*5 +: 5]))
                        waw_bits[l] = 1'b1;
                end
    end

    assign raw_dependency = raw_bits;
    assign waw_dependency = waw_bits;
endmodule
