`timescale 1ns/1ps
module register_bank_tb;
    reg clk = 0;
    reg reset = 1;
    reg [39:0] read_addresses = 0;
    wire [255:0] read_data;
    reg [3:0] write_enable = 0;
    reg [19:0] write_addresses = 0;
    reg [127:0] write_data = 0;
    integer i;
    integer pass_count = 0;

    register_bank dut (.*);
    always #5 clk = ~clk;

    task check;
        input [31:0] got;
        input [31:0] expected;
        begin
            if (got !== expected)
                $fatal(1,"register_bank: esperado %h, obtido %h",expected,got);
            pass_count = pass_count + 1;
        end
    endtask

    initial begin
        $dumpfile("target/wave.vcd");
        $dumpvars(0,register_bank_tb);
        @(posedge clk); #1;
        reset = 0;
        // Verificar todas as leituras apos reset.
        for (i=0;i<8;i=i+1) read_addresses[i*5 +: 5]=i;
        #1;
        for (i=0;i<8;i=i+1) check(read_data[i*32 +: 32],32'd0);

        // Quatro escritas independentes no mesmo ciclo.
        @(negedge clk);
        write_enable = 4'b1111;
        for (i=0;i<4;i=i+1) begin
            write_addresses[i*5 +: 5] = i + 1;
            write_data[i*32 +: 32] = 32'h11110000 + i;
        end
        @(posedge clk); #1;
        for (i=0;i<4;i=i+1) check(read_data[(i+1)*32 +: 32],32'h11110000 + i);

        // x0 permanece zero.
        @(negedge clk);
        write_enable = 4'b0001;
        write_addresses[4:0] = 5'd0;
        write_data[31:0] = 32'hffffffff;
        @(posedge clk); #1;
        check(read_data[31:0],32'd0);

        // Mesmo destino nas quatro lanes: vence a mais jovem (3).
        @(negedge clk);
        write_enable = 4'b1111;
        for (i=0;i<4;i=i+1) begin
            write_addresses[i*5 +: 5] = 5'd7;
            write_data[i*32 +: 32] = 32'habc00000 + i;
        end
        @(posedge clk); #1;
        check(read_data[7*32 +: 32],32'habc00003);

        // Lane 3 desabilitada: lane 2 vence, sem afetar x1.
        @(negedge clk);
        write_enable = 4'b0111;
        write_data[95:64] = 32'h00001234;
        @(posedge clk); #1;
        check(read_data[7*32 +: 32],32'h00001234);
        check(read_data[1*32 +: 32],32'h11110000);

        // Reset descarta escrita que ocorreria no mesmo ciclo.
        @(negedge clk);
        reset = 1;
        write_enable = 4'b1111;
        @(posedge clk); #1;
        for (i=0;i<8;i=i+1) check(read_data[i*32 +: 32],32'd0);

        $display("PASS register_bank_tb (%0d verificacoes)",pass_count);
        $finish;
    end
endmodule
