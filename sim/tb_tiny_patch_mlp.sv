`timescale 1ns/1ps
module tb_tiny_patch_mlp;
    logic clk = 0;
    logic rstn = 0;
    logic s_valid = 0;
    logic s_ready;
    logic [127:0] features = '0;
    logic m_valid;
    logic m_ready = 0;
    logic detected;
    logic signed [31:0] score_q12;
    integer i;

    always #5 clk = ~clk;

    tiny_patch_mlp dut (
        .aclk(clk), .aresetn(rstn),
        .s_valid(s_valid), .s_ready(s_ready), .s_features(features),
        .m_valid(m_valid), .m_ready(m_ready),
        .m_detected(detected), .m_score_q12(score_q12)
    );

    task automatic evaluate_patch(input bit centered, input bit expected);
        integer bit_index;
        begin
            @(negedge clk);
            features = '0;
            for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1)
                features[bit_index*8 +: 8] = 8'd51;
            if (centered) begin
                features[5*8 +: 8] = 8'd230;
                features[6*8 +: 8] = 8'd230;
                features[9*8 +: 8] = 8'd230;
                features[10*8 +: 8] = 8'd230;
            end else begin
                features[0*8 +: 8] = 8'd230;
                features[1*8 +: 8] = 8'd230;
                features[4*8 +: 8] = 8'd230;
                features[5*8 +: 8] = 8'd230;
            end
            s_valid = 1;
            wait (s_ready);
            @(posedge clk); #1; s_valid = 0;
            wait (m_valid); #1;
            if (detected !== expected)
                $fatal(1, "tiny MLP mismatch centered=%0d score_q12=%0d detected=%0d",
                       centered, score_q12, detected);
            repeat (3) begin
                @(posedge clk); #1;
                if (!m_valid || detected !== expected)
                    $fatal(1, "result did not remain stable under backpressure");
            end
            @(negedge clk); m_ready = 1;
            @(posedge clk); #1;
            @(negedge clk); m_ready = 0;
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk); rstn = 1;
        evaluate_patch(1, 1);
        evaluate_patch(0, 0);
        $display("PASS tiny quantized MLP centered-target detection and output backpressure");
        $finish;
    end
endmodule
