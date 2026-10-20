`timescale 1ns/1ps
module memory_byte_enabled_tb;
    reg clk=0,request_valid=0,write_enable=0;
    reg [31:0] address=0,write_data=0;
    reg [3:0] byte_enable=0;
    wire [31:0] read_data;
    wire address_valid;
    memory_byte_enabled dut (.*);
    always #5 clk=~clk;

    task check;
        input [31:0] expected;
        begin
            #1;
            if(read_data !== expected)
                $fatal(1,"memory_byte_enabled: expected=%h got=%h",expected,read_data);
        end
    endtask
    task write_word;
        input [31:0] a,d;
        input [3:0] strobe;
        begin
            @(negedge clk);
            address=a;write_data=d;byte_enable=strobe;
            request_valid=1;write_enable=1;
            @(posedge clk); #1;
            write_enable=0;
        end
    endtask

    initial begin
        $dumpfile("target/wave.vcd");$dumpvars(0,memory_byte_enabled_tb);
        write_word(32'h0,32'h11223344,4'b1111);
        check(32'h11223344);
        write_word(32'h0,32'h0000aa00,4'b0010);
        check(32'h1122aa44);
        write_word(32'h0,32'hbbcc0000,4'b1100);
        check(32'hbbccaa44);

        // Enderecos acima da capacidade nao podem sobrescrever word 0.
        write_word(32'h00000400,32'hdeadbeef,4'b1111);
        if (address_valid !== 1'b0) $fatal(1,"out of range deve ser invalido");
        check(32'h00000000);
        @(negedge clk);
        request_valid=1;write_enable=0;address=0;
        check(32'hbbccaa44);

        // Endereco desalinhado na interface da memoria (a LSU deve alinhar).
        @(negedge clk);address=32'h00000001;
        #1; // Permitir atualizacao combinacional de address_valid.
        if (address_valid !== 1'b0) $fatal(1,"endereco desalinhado");
        check(32'h00000000);
        @(negedge clk);address=0;request_valid=0;
        check(32'h00000000);
        $display("PASS memory_byte_enabled_tb");$finish;
    end
endmodule
