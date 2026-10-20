`timescale 1ns/1ps
/* Integracao 4-wide real: quatro LSUs -> RAM 4-port -> WB 4 portas -> RF.
 * Ainda nao eh integracao em central_processing_unit (frontend somente).
 */
module gabriel_integration_tb;
    reg clk=0,reset=1;
    reg [3:0] lane_valid=0,mem_read=0,mem_write=0;
    reg [127:0] effective_address=0,store_data=0;
    reg [11:0] funct3=0;
    wire [127:0] load_result;
    wire [3:0] request_grant,memory_valid,load_valid,misaligned,illegal_op,out_of_range;
    memory_subsystem_4wide mem4 (.*);

    reg [3:0] valid_in=0,reg_write_in=0,exception_mask=0;
    reg [19:0] rd_in=0;
    reg [7:0] wb_sel=0;
    reg [127:0] alu_result=0,pc_plus4=0,upper_immediate=0;
    wire [127:0] mem_result=load_result;
    wire [3:0] write_enable;
    wire [19:0] write_addresses;
    wire [127:0] wb_write_data;
    writeback_unit wb(
        .valid_in(valid_in),.reg_write_in(reg_write_in),.exception_mask(exception_mask),
        .rd_in(rd_in),.wb_sel(wb_sel),.alu_result(alu_result),.mem_result(mem_result),
        .pc_plus4(pc_plus4),.upper_immediate(upper_immediate),
        .write_enable(write_enable),.write_addresses(write_addresses),.write_data(wb_write_data)
    );
    reg [39:0] read_addresses=0;
    wire [255:0] read_data;
    register_bank rf(
        .clk(clk),.reset(reset),.read_addresses(read_addresses),.read_data(read_data),
        .write_enable(write_enable),.write_addresses(write_addresses),.write_data(wb_write_data)
    );
    always #5 clk=~clk;

    integer i;
    initial begin
        $dumpfile("target/wave.vcd");$dumpvars(0,gabriel_integration_tb);
        @(posedge clk);#1;reset=0;
        @(negedge clk);
        // Quatro SW simultaneos para enderecos diferentes.
        lane_valid=4'hf;mem_write=4'hf;
        effective_address={32'h2c,32'h28,32'h24,32'h20};
        store_data={32'hbadc0ffe,32'hdefaced0,32'h10203040,32'h80ff5678};
        funct3={4{3'b010}};
        #1;
        if(request_grant!==4'hf || memory_valid!==4'hf) $fatal(1,"four simultaneous stores");
        @(posedge clk);#1;
        @(negedge clk);
        // Quatro LW simultaneos nos mesmos enderecos -> quatro writebacks.
        mem_write=0;mem_read=4'hf;
        valid_in=4'hf;reg_write_in=4'hf;
        wb_sel={4{2'b01}};
        rd_in={5'd13,5'd12,5'd11,5'd10};
        read_addresses={5'd0,5'd0,5'd0,5'd0,5'd13,5'd12,5'd11,5'd10};
        #1;
        if(load_valid!==4'hf || write_enable!==4'hf) $fatal(1,"four simultaneous loads/writebacks");
        @(posedge clk);#1;
        if(read_data[31:0]!==32'h80ff5678 ||
           read_data[63:32]!==32'h10203040 ||
           read_data[95:64]!==32'hdefaced0 ||
           read_data[127:96]!==32'hbadc0ffe)
            $fatal(1,"four concurrent load-to-register commits");
        // WAW x12: younger lane wins, zero register remains zero.
        @(negedge clk);
        lane_valid=0;mem_read=0;valid_in=4'hf;reg_write_in=4'hf;
        wb_sel=0;
        rd_in={5'd12,5'd12,5'd12,5'd0};
        alu_result={32'h400,32'h300,32'h200,32'h100};
        read_addresses[4:0]=5'd0;
        read_addresses[9:5]=5'd12;
        @(posedge clk);#1;
        if(read_data[31:0]!==32'b0 || read_data[63:32]!==32'h400)
            $fatal(1,"WAW or x0 priority");
        $display("PASS gabriel_integration_tb");$finish;
    end
endmodule
