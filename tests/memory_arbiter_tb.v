`timescale 1ns/1ps
module memory_arbiter_tb;
    reg [3:0] request_valid=0,request_write=0;
    reg [127:0] request_address=0,request_write_data=0;
    reg [15:0] request_byte_enable=0;
    wire [3:0] grant,stalled_requests,issue_allow_mask,memory_valid,memory_write;
    wire [127:0] memory_address,memory_write_data;
    wire [15:0] memory_byte_enable;
    memory_arbiter dut (.*);
    integer i;
    initial begin
        $dumpfile("target/wave.vcd");$dumpvars(0,memory_arbiter_tb);
        for(i=0;i<4;i=i+1) begin
            request_address[i*32 +:32]=32'h100+i*4;
            request_write_data[i*32 +:32]=32'hface0000+i;
            request_byte_enable[i*4 +:4]=4'hf;
        end
        #1;
        if(grant!==0 || stalled_requests!==0 || issue_allow_mask!==4'hf) $fatal(1,"idle");
        request_valid=4'b1111;request_write=4'b1011;
        #1;
        if(grant!==4'hf || stalled_requests!==0 || issue_allow_mask!==4'hf ||
           memory_valid!==4'hf || memory_write!==4'b1011 ||
           memory_address!==request_address || memory_write_data!==request_write_data ||
           memory_byte_enable!==request_byte_enable)
            $fatal(1,"all four ports must pass in one cycle");
        request_valid=4'b0101;#1;
        if(grant!==4'b0101 || memory_write!==4'b0001) $fatal(1,"sparse lanes");
        // Arbiter deve permitir conflitos no mesmo endereco: RAM resolve ordem.
        request_valid=4'b1111;
        request_address={4{32'h10}};
        #1;
        if(grant!==4'hf || memory_address!=={4{32'h10}}) $fatal(1,"same word conflict");
        $display("PASS memory_arbiter_tb");$finish;
    end
endmodule
