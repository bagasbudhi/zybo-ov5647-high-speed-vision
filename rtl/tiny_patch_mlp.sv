`timescale 1ns/1ps
// Standalone quantized 16-8-1 ReLU MLP patch classifier.
// Inputs are 4x4 pooled grayscale values (16 unsigned bytes), lowest feature
// in s_features[7:0]. It reuses one multiply per cycle and classifies in 136
// clocks. This block is not connected to the camera/HDMI block design yet.
module tiny_patch_mlp (
    input  logic         aclk,
    input  logic         aresetn,
    input  logic         s_valid,
    output logic         s_ready,
    input  logic [127:0] s_features,
    output logic         m_valid,
    input  logic         m_ready,
    output logic         m_detected,
    output logic signed [31:0] m_score_q12
);
    typedef enum logic [1:0] {IDLE, LAYER1, LAYER2, RESULT} state_t;
    state_t state;
    logic [7:0] pixels [0:15];
    logic [7:0] hidden [0:7];
    logic [2:0] neuron;
    logic [3:0] tap;
    logic signed [31:0] accum1;
    logic signed [31:0] accum2;
    logic signed [31:0] mac1_next;
    logic signed [31:0] mac2_next;

    `include "tiny_patch_weights.svh"

    assign s_ready = (state == IDLE);
    assign m_valid = (state == RESULT);

    always_comb begin
        mac1_next = accum1 + ($signed(nn_weight1(neuron, tap)) * $signed({1'b0, pixels[tap]}));
        mac2_next = accum2 + ($signed(nn_weight2(neuron)) * $signed({1'b0, hidden[neuron]}));
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state <= IDLE;
            neuron <= '0;
            tap <= '0;
            accum1 <= '0;
            accum2 <= '0;
            m_detected <= 1'b0;
            m_score_q12 <= '0;
            for (integer k = 0; k < 8; k = k + 1) hidden[k] <= '0;
            for (integer k = 0; k < 16; k = k + 1) pixels[k] <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (s_valid) begin
                        for (integer k = 0; k < 16; k = k + 1)
                            pixels[k] <= s_features[k*8 +: 8];
                        neuron <= 0;
                        tap <= 0;
                        accum1 <= nn_bias1(0);
                        state <= LAYER1;
                    end
                end
                LAYER1: begin
                    if (tap == 15) begin
                        if (mac1_next <= 0) hidden[neuron] <= 0;
                        else if (((mac1_next + 128) >>> 8) > 255) hidden[neuron] <= 8'hFF;
                        else hidden[neuron] <= (mac1_next + 128) >>> 8;
                        tap <= 0;
                        if (neuron == 7) begin
                            neuron <= 0;
                            accum2 <= NN_BIAS2_Q12;
                            state <= LAYER2;
                        end else begin
                            neuron <= neuron + 1'b1;
                            accum1 <= nn_bias1(neuron + 1'b1);
                        end
                    end else begin
                        tap <= tap + 1'b1;
                        accum1 <= mac1_next;
                    end
                end
                LAYER2: begin
                    if (neuron == 7) begin
                        m_score_q12 <= mac2_next;
                        m_detected <= (mac2_next >= NN_SCORE_THRESHOLD_Q12);
                        state <= RESULT;
                    end else begin
                        accum2 <= mac2_next;
                        neuron <= neuron + 1'b1;
                    end
                end
                RESULT: begin
                    if (m_ready) state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
