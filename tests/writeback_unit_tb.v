`timescale 1ns/1ps
module writeback_unit_tb;
    reg [3:0] valid_in=0,reg_write_in=0,exception_mask=0;
    reg [19:0] rd_in=0;
    reg [7:0] wb_sel=0;
    reg [127:0] alu_result=0,mem_result=0,pc_plus4=0,upper_immediate=0;
    wire [3:0] write_enable;
    wire [19:0] write_addresses;
    wire [127:0] write_data;
    writeback_unit dut (.*);
    integer i;
    initial begin
        $dumpfile("target/wave.vcd");$dumpvars(0,writeback_unit_tb);
        for(i=0;i<4;i=i+1) begin
            rd_in[i*5 +: 5]=i+1;
            wb_sel[i*2 +: 2]=i;
            alu_result[i*32 +: 32]=32'h1000+i;
            mem_result[i*32 +: 32]=32'h2000+i;
            pc_plus4[i*32 +: 32]=32'h3000+i;
            upper_immediate[i*32 +: 32]=32'h4000+i;
        end
        valid_in=4'b1111;reg_write_in=4'b1111;#1;
        if(write_enable!==4'b1111 || write_addresses!==rd_in
          || write_data[31:0]!==32'h1000
          || write_data[63:32]!==32'h2001
          || write_data[95:64]!==32'h3002
          || write_data[127:96]!==32'h4003)
            $fatal(1,"wb source selection");
        exception_mask=4'b0100;#1;
        if(write_enable!==4'b1011) $fatal(1,"wb exception gating");
        rd_in[4:0]=0;#1;
        if(write_enable!==4'b1010) $fatal(1,"wb x0");
        valid_in=4'b0001;exception_mask=0;#1;
        if(write_enable!==4'b0000) $fatal(1,"wb x0 and valid");
        valid_in=4'b1111;reg_write_in=4'b0010;#1;
        if(write_enable!==4'b0010) $fatal(1,"wb reg write mask");
        $display("PASS writeback_unit_tb");$finish;
    end
endmodule
