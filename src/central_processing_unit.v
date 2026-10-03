module central_processing_unit (
    input wire clk,
    input wire reset,
    output wire [31:0] pc
);

    program_counter program_counter_instance (
        .clk(clk),
        .reset(reset),
        .value(pc)
    );

endmodule