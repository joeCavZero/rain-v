`timescale 1ns/1ps
module load_store_unit_tb;
    reg [31:0] address=0,store_data=0,raw_word=0;
    reg [2:0] funct3=0;
    reg mem_read=0,mem_write=0;
    wire [31:0] aligned_address,store_word,load_result;
    wire [3:0] store_mask;
    wire access_valid,misaligned,illegal_op;
    load_store_unit dut (.*);
    task check_load;
        input [31:0] a,w,expected;
        input [2:0] fmt;
        begin
            address=a;raw_word=w;funct3=fmt;
            mem_read=1;mem_write=0;#1;
            if (!access_valid || misaligned || illegal_op || load_result !== expected)
                $fatal(1,"load a=%h fmt=%b expected=%h got=%h",a,fmt,expected,load_result);
        end
    endtask
    task check_store;
        input [31:0] a,d,expected_word;
        input [2:0] fmt;
        input [3:0] expected_mask;
        begin
            address=a;store_data=d;funct3=fmt;
            mem_read=0;mem_write=1;#1;
            if (!access_valid || misaligned || illegal_op || store_mask !== expected_mask || store_word !== expected_word)
                $fatal(1,"store a=%h fmt=%b mask=%b/%b word=%h/%h",a,fmt,store_mask,expected_mask,store_word,expected_word);
            if (aligned_address !== {a[31:2],2'b00}) $fatal(1,"aligned address");
        end
    endtask
    initial begin
        $dumpfile("target/wave.vcd");$dumpvars(0,load_store_unit_tb);
        check_load(32'd0,32'h80ff7f01,32'h00000001,3'b000);
        check_load(32'd2,32'h80ff7f01,32'hffffffff,3'b000);
        check_load(32'd3,32'h80ff7f01,32'hffffff80,3'b000);
        check_load(32'd3,32'h80ff7f01,32'h00000080,3'b100);
        check_load(32'd0,32'h80ff7f01,32'h00007f01,3'b101);
        check_load(32'd2,32'h80ff7f01,32'hffff80ff,3'b001);
        check_load(32'd2,32'h80ff7f01,32'h000080ff,3'b101);
        check_load(32'd0,32'h80ff7f01,32'h80ff7f01,3'b010);
        check_store(32'd0,32'h12345678,32'h00000078,3'b000,4'b0001);
        check_store(32'd3,32'h12345678,32'h78000000,3'b000,4'b1000);
        check_store(32'd2,32'h12345678,32'h56780000,3'b001,4'b1100);
        check_store(32'd0,32'h12345678,32'h12345678,3'b010,4'b1111);
        // Halfword, word e suas leituras nao podem ser desalinhadas.
        address=1;funct3=3'b001;mem_read=1;mem_write=0;#1;
        if (!misaligned || access_valid || load_result!==0) $fatal(1,"misaligned LH");
        address=2;funct3=3'b010;#1;
        if (!misaligned || access_valid) $fatal(1,"misaligned LW");
        mem_read=0;mem_write=1;address=3;funct3=3'b010;#1;
        if (!misaligned || access_valid || store_mask!==0) $fatal(1,"misaligned SW");
        funct3=3'b111;#1;
        if (!illegal_op || access_valid) $fatal(1,"illegal store");
        mem_read=1;mem_write=1;#1;
        if (!illegal_op || access_valid) $fatal(1,"read/write overlap");
        mem_read=0;mem_write=0;#1;
        if (access_valid || illegal_op || misaligned || store_mask!==0) $fatal(1,"idle");
        $display("PASS load_store_unit_tb");$finish;
    end
endmodule
