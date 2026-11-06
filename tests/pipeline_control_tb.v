`timescale 1ns/1ps
/* pipeline_control: envelhecimento do rastro de escritas em voo (1 e 2
   estagios), STAGES = 0 publicando sempre zero, reset, stall com prioridade
   do redirect e repasse de redirect/redirect_target.
*/
module pipeline_control_tb;
reg clk = 0, reset = 1;
reg redirect = 0;
reg [31:0] redirect_target = 32'h100;
reg stall_request = 0;
reg [3:0] push_valid = 0;
reg [19:0] push_rd = 0;

wire stall1, redirect_out1; wire [31:0] redirect_target_out1;
wire [7:0] inflight_valid1; wire [39:0] inflight_rd1;

wire stall2, redirect_out2; wire [31:0] redirect_target_out2;
wire [7:0] inflight_valid2; wire [39:0] inflight_rd2;

wire stall0, redirect_out0; wire [31:0] redirect_target_out0;
wire [7:0] inflight_valid0; wire [39:0] inflight_rd0;

pipeline_control #(.INFLIGHT_STAGES(1)) dut1 (
    .clk(clk), .reset(reset),
    .redirect(redirect), .redirect_target(redirect_target),
    .stall_request(stall_request),
    .push_valid(push_valid), .push_rd(push_rd),
    .stall_out(stall1), .redirect_out(redirect_out1),
    .redirect_target_out(redirect_target_out1),
    .inflight_valid(inflight_valid1), .inflight_rd(inflight_rd1));

pipeline_control #(.INFLIGHT_STAGES(2)) dut2 (
    .clk(clk), .reset(reset),
    .redirect(redirect), .redirect_target(redirect_target),
    .stall_request(stall_request),
    .push_valid(push_valid), .push_rd(push_rd),
    .stall_out(stall2), .redirect_out(redirect_out2),
    .redirect_target_out(redirect_target_out2),
    .inflight_valid(inflight_valid2), .inflight_rd(inflight_rd2));

pipeline_control #(.INFLIGHT_STAGES(0)) dut0 (
    .clk(clk), .reset(reset),
    .redirect(redirect), .redirect_target(redirect_target),
    .stall_request(stall_request),
    .push_valid(push_valid), .push_rd(push_rd),
    .stall_out(stall0), .redirect_out(redirect_out0),
    .redirect_target_out(redirect_target_out0),
    .inflight_valid(inflight_valid0), .inflight_rd(inflight_rd0));

always #5 clk = ~clk;

task expect_inflight;
    input [7:0] e1, e2;
    input [255:0] msg;
    begin
        if (inflight_valid1 !== e1 || inflight_valid2 !== e2)
            $fatal(1, "%0s: inflight1=%b inflight2=%b, esperado %b e %b",
                   msg, inflight_valid1, inflight_valid2, e1, e2);
    end
endtask

task pulse;
    @(posedge clk); #1;
endtask

initial begin
    $dumpfile("target/wave_pipeline_control.vcd"); $dumpvars(0, pipeline_control_tb);

    @(negedge clk); reset = 0; push_valid = 0;
    pulse;
    expect_inflight(8'b0, 8'b0, "reset");

    // Push da lane 0 escrevendo x5: stage0 nos DUTs de 1 e 2 estagios.
    @(negedge clk); push_valid = 4'b0001;
    push_rd[4:0] = 5'd5; push_rd[9:5] = 5'd0; push_rd[14:10] = 5'd0; push_rd[19:15] = 5'd0;
    pulse;
    expect_inflight(8'b00000001, 8'b00000001, "push lane 0 x5: stage0");

    // Push da lane 3 (rd x9): DUT1 substitui o stage0; DUT2 envelhece o x5
    // (lane 0 passa ao slot 4, mantendo a posicao da lane no grupo).
    @(negedge clk); push_valid[0] = 1'b0; push_valid[3] = 1'b1; push_rd[19:15] = 5'd9;
    pulse;
    expect_inflight(8'b00001000, 8'b00011000, "push lane 3 x9 + aging");

    // Sem push: DUT1 descarta; DUT2 envelhece (x9 vai do slot 3 ao slot 7).
    @(negedge clk); push_valid = 0;
    pulse;
    expect_inflight(8'b00000000, 8'b10000000, "aging do grupo");

    // DUT2 limpa no ciclo seguinte.
    pulse;
    expect_inflight(8'b00000000, 8'b00000000, "rastro vazio");

    // Reset limpa o rastro mesmo com push pendente.
    @(negedge clk); push_valid = 4'b1111;
    push_rd[4:0] = 5'd1; push_rd[9:5] = 5'd2; push_rd[14:10] = 5'd3; push_rd[19:15] = 5'd4;
    @(negedge clk); reset = 1; push_valid = 0;
    pulse;
    expect_inflight(8'b00000000, 8'b00000000, "reset limpa o rastro");
    @(negedge clk); reset = 0;

    // STAGES = 0 publica sempre zero e ignora push; DUT1 captura e descarta.
    @(negedge clk); push_valid = 4'b0010; push_rd[9:5] = 5'd11;
    pulse;
    expect_inflight(8'b00000010, 8'b00000010, "push lane 1 x11");
    if (inflight_valid0 !== 8'b0 || inflight_rd0 !== 40'b0)
        $fatal(1, "STAGES=0 deveria publicar sempre zero");
    @(negedge clk); push_valid = 0;
    pulse;
    expect_inflight(8'b00000000, 8'b00100000, "aging da lane 1");
    pulse;
    expect_inflight(8'b00000000, 8'b00000000, "rastro vazio de novo");

    // Stall sai direto; redirect manda no stall e repassa o alvo.
    @(negedge clk); stall_request = 1;
    pulse;
    if (stall1 !== 1'b1 || redirect_out1 !== 1'b0)
        $fatal(1, "stall sem redirect deveria sair 1");
    @(negedge clk); redirect = 1; redirect_target = 32'h00000200;
    pulse;
    if (stall1 !== 1'b0 || redirect_out1 !== 1'b1 ||
        redirect_target_out1 !== 32'h00000200)
        $fatal(1, "redirect deveria silenciar o stall e repassar o alvo");
    if (redirect_out2 !== 1'b1 || redirect_target_out2 !== 32'h00000200)
        $fatal(1, "DUT2 deveria repassar o redirect igual");
    if (stall0 !== 1'b0 || redirect_out0 !== 1'b1)
        $fatal(1, "DUT0 deveria comportar os sinais de controle igual");
    @(negedge clk); redirect = 0; stall_request = 0;
    pulse;

    $display("PASS pipeline_control");
    $finish;
end
endmodule
