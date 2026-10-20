`timescale 1ns/1ps
module memory_subsystem_4wide_tb;
    reg clk=0;
    reg [3:0] lane_valid=0,mem_read=0,mem_write=0;
    reg [127:0] effective_address=0,store_data=0;
    reg [11:0] funct3=0;
    wire [127:0] load_result;
    wire [3:0] request_grant,memory_valid,load_valid,misaligned,illegal_op,out_of_range;
    memory_subsystem_4wide dut(.*);
    always #5 clk=~clk;
    task set_lane;
        input integer lane;
        input [31:0] addr,data;
        input [2:0] format;
        input is_load,is_store;
        begin
            lane_valid[lane]=1;
            effective_address[lane*32 +:32]=addr;
            store_data[lane*32 +:32]=data;
            funct3[lane*3 +:3]=format;
            mem_read[lane]=is_load;
            mem_write[lane]=is_store;
        end
    endtask
    task clear_lanes;
        begin
            lane_valid=0;mem_read=0;mem_write=0;
            effective_address=0;store_data=0;funct3=0;
        end
    endtask
    task expect_load;
        input integer lane;
        input [31:0] expected;
        begin
            #1;
            if(load_result[lane*32 +:32]!==expected || !load_valid[lane])
                $fatal(1,"LSU lane %0d: expected %h got %h valid=%b",
                    lane,expected,load_result[lane*32 +:32],load_valid[lane]);
        end
    endtask
    initial begin
        $dumpfile("target/wave.vcd");$dumpvars(0,memory_subsystem_4wide_tb);
        // Quatro stores simultaneas, formatos diferentes.
        @(negedge clk);
        set_lane(0,32'h00,32'h80ff2233,3'b010,0,1); // SW
        set_lane(1,32'h04,32'habcd0099,3'b010,0,1); // SW
        set_lane(2,32'h08,32'h0000feed,3'b001,0,1); // SH
        set_lane(3,32'h0f,32'h000000ee,3'b000,0,1); // SB
        #1;
        if(request_grant!==4'hf || memory_valid!==4'hf ||
           misaligned!==0 || illegal_op!==0 || out_of_range!==0)
            $fatal(1,"four stores should be accepted in parallel");
        @(posedge clk);#1;
        @(negedge clk);clear_lanes();
        // Quatro loads simultaneas, LB/LHU/LW/LBU.
        set_lane(0,32'h03,0,3'b000,1,0); // LB sign extension 0x80
        set_lane(1,32'h08,0,3'b101,1,0); // LHU 0xfeed
        set_lane(2,32'h04,0,3'b010,1,0); // LW
        set_lane(3,32'h0f,0,3'b100,1,0); // LBU 0xee
        #1;
        if(load_valid!==4'hf) $fatal(1,"four loads must be ready together");
        expect_load(0,32'hffffff80);expect_load(1,32'h0000feed);
        expect_load(2,32'habcd0099);expect_load(3,32'h000000ee);
        // Mesmo word, duas stores e dois loads: forwarding por idade.
        @(negedge clk);clear_lanes();
        set_lane(0,32'h10,32'h11223344,3'b010,0,1);
        set_lane(1,32'h10,0,3'b010,1,0);
        set_lane(2,32'h11,32'h000000ff,3'b000,0,1);
        set_lane(3,32'h10,0,3'b010,1,0);
        #1;
        if(request_grant!==4'hf || memory_valid!==4'hf || load_valid!==4'b1010)
            $fatal(1,"same word mix grants");
        expect_load(1,32'h11223344);
        expect_load(3,32'h1122ff44);
        @(posedge clk);#1;
        @(negedge clk);clear_lanes();
        set_lane(0,32'h10,0,3'b010,1,0);
        expect_load(0,32'h1122ff44);
        // Excecoes locais: desalinhamento, opcode ilegal, fora da faixa.
        @(negedge clk);clear_lanes();
        set_lane(0,32'h01,0,3'b010,1,0); // LW misaligned
        set_lane(1,32'h00,0,3'b111,1,0); // formato ilegal
        set_lane(2,32'h400,0,3'b010,1,0); // out of range
        set_lane(3,32'h00,0,3'b010,1,0); // valido
        #1;
        if(misaligned!==4'b0001 || illegal_op!==4'b0010 ||
           out_of_range!==4'b0100 || memory_valid!==4'b0000 ||
           request_grant!==4'b0000 || load_valid!==4'b0000 ||
           load_result[95:0]!==96'b0)
            $fatal(1,"exceptions must not commit, mask=%b",memory_valid);
        // Nao permitir store de instrucao mais jovem apos fault da mais antiga.
        @(negedge clk);clear_lanes();
        set_lane(0,32'h30,32'hcafecafe,3'b010,0,1);
        @(posedge clk);#1;
        @(negedge clk);clear_lanes();
        set_lane(0,32'h01,0,3'b010,1,0); // lane0 falha
        set_lane(1,32'h30,32'hbadbadba,3'b010,0,1); // NAO pode gravar
        set_lane(2,32'h30,0,3'b010,1,0); // NAO pode concluir
        #1;
        if(request_grant!==0 || load_valid!==0)
            $fatal(1,"younger memory accesses must be blocked on older fault");
        @(posedge clk);#1;
        @(negedge clk);clear_lanes();
        set_lane(0,32'h30,0,3'b010,1,0);
        expect_load(0,32'hcafecafe);
        $display("PASS memory_subsystem_4wide_tb");$finish;
    end
endmodule
