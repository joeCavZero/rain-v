`timescale 1ns/1ps
module memory_4wide_tb;
    reg clk=0;
    reg [3:0] request_valid=0,write_enable=0;
    reg [127:0] address=0,write_data=0;
    reg [15:0] byte_enable=0;
    wire [127:0] read_data;
    wire [3:0] address_valid;
    memory_4wide dut(.*);
    always #5 clk=~clk;
    task set_port;
        input integer lane;
        input [31:0] addr,value;
        input [3:0] strb;
        input write_en;
        begin
            address[lane*32 +:32]=addr;
            write_data[lane*32 +:32]=value;
            byte_enable[lane*4 +:4]=strb;
            request_valid[lane]=1;
            write_enable[lane]=write_en;
        end
    endtask
    task check_port;
        input integer lane;
        input [31:0] expected;
        begin
            #1;
            if(read_data[lane*32 +:32]!==expected)
                $fatal(1,"lane %0d: expected %h got %h",lane,expected,read_data[lane*32 +:32]);
        end
    endtask
    task clear_ports;
        begin
            request_valid=0;write_enable=0;address=0;write_data=0;byte_enable=0;
        end
    endtask
    initial begin
        $dumpfile("target/wave.vcd");$dumpvars(0,memory_4wide_tb);
        // 4 SW em quatro palavras no MESMO ciclo.
        @(negedge clk);
        set_port(0,32'h00,32'h11223344,4'hf,1);
        set_port(1,32'h04,32'haabbccdd,4'hf,1);
        set_port(2,32'h08,32'h12345678,4'hf,1);
        set_port(3,32'h0c,32'hdeadbeef,4'hf,1);
        #1; // Esperar propagacao dos enderecos pelas quatro portas.
        if(address_valid!==4'hf) $fatal(1,"valid addresses");
        @(posedge clk);#1;
        @(negedge clk);clear_ports();
        set_port(0,32'h00,0,0,0);set_port(1,32'h04,0,0,0);
        set_port(2,32'h08,0,0,0);set_port(3,32'h0c,0,0,0);
        check_port(0,32'h11223344);check_port(1,32'haabbccdd);
        check_port(2,32'h12345678);check_port(3,32'hdeadbeef);
        // 4 stores MESMA palavra: combinar bytes e resolver WAW.
        @(negedge clk);clear_ports();
        set_port(0,32'h00,32'h000000aa,4'b0001,1);
        set_port(1,32'h00,32'h0000bb00,4'b0010,1);
        set_port(2,32'h00,32'h00cc0000,4'b0100,1);
        set_port(3,32'h00,32'hdd000000,4'b1000,1);
        @(posedge clk);#1;
        @(negedge clk);clear_ports();set_port(0,32'h00,0,0,0);
        check_port(0,32'hddccbbaa);
        // Quatro stores ao MESMO byte: lane 3 (mais nova) vence.
        @(negedge clk);clear_ports();
        set_port(0,32'h00,32'h00000011,4'b0001,1);
        set_port(1,32'h00,32'h00000022,4'b0001,1);
        set_port(2,32'h00,32'h00000033,4'b0001,1);
        set_port(3,32'h00,32'h00000044,4'b0001,1);
        @(posedge clk);#1;
        @(negedge clk);clear_ports();set_port(0,32'h00,0,0,0);
        check_port(0,32'hddccbb44);
        // Interleaving: load lane 0 antigo, store lane 1, load lane 2,
        // store lane 3; leitura lane 2 ve a store lane 1, nao lane 3.
        @(negedge clk);clear_ports();
        set_port(0,32'h00,0,0,0);
        set_port(1,32'h00,32'h00ff0000,4'b0100,1);
        set_port(2,32'h00,0,0,0);
        set_port(3,32'h00,32'h00008800,4'b0010,1);
        check_port(0,32'hddccbb44);
        check_port(2,32'hddffbb44);
        @(posedge clk);#1;
        @(negedge clk);clear_ports();set_port(0,32'h00,0,0,0);
        check_port(0,32'hddff8844);
        // Quatro loads no mesmo endereco simultaneamente.
        @(negedge clk);clear_ports();
        set_port(0,32'h00,0,0,0);set_port(1,32'h00,0,0,0);
        set_port(2,32'h00,0,0,0);set_port(3,32'h00,0,0,0);
        check_port(0,32'hddff8844);check_port(1,32'hddff8844);
        check_port(2,32'hddff8844);check_port(3,32'hddff8844);
        // Desalinhado, fora da memoria e idle nao causam alias ou escrita.
        @(negedge clk);clear_ports();
        set_port(0,32'h00000400,32'hdeadbeef,4'hf,1);
        set_port(1,32'h00000001,32'hdeadbeef,4'hf,1);
        set_port(2,32'h00000000,0,0,0);
        #1;
        if(address_valid[1:0]!==2'b00) $fatal(1,"invalid addresses");
        check_port(0,0);check_port(1,0);check_port(2,32'hddff8844);
        @(posedge clk);#1;
        @(negedge clk);clear_ports();set_port(0,32'h00,0,0,0);
        check_port(0,32'hddff8844);
        clear_ports();#1;
        if(read_data!==128'b0) $fatal(1,"idle must not expose data");
        $display("PASS memory_4wide_tb");$finish;
    end
endmodule
