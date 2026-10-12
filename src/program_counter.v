/* PC RV32I: avanca pelo numero de instrucoes buscadas; aceita redirecionamento. */
module program_counter (
    input wire clk, reset,
    input wire enable,
    input wire redirect,
    input wire [31:0] redirect_target,
    input wire [2:0] advance_words,
    output reg [31:0] value
);
    always @(posedge clk) begin
        if (reset) value <= 32'b0;
        else if (redirect) value <= redirect_target;
        else if (enable) value <= value + {27'b0,advance_words,2'b00};
    end
endmodule
