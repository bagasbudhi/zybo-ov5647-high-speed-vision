`timescale 1ns/1ps
// AXI4-Stream RGB888 pass-through with a per-frame bright-pixel ROI metric.
// Luma approximation is (R + 2*G + B)/4. Results latch at completed frame end.
module axis_bright_roi_detector #(
    parameter integer WIDTH = 640,
    parameter integer HEIGHT = 480,
    parameter integer ROI_X0 = 160,
    parameter integer ROI_Y0 = 120,
    parameter integer ROI_X1 = 479,
    parameter integer ROI_Y1 = 359,
    parameter integer LUMA_THRESHOLD = 32
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [23:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tuser,
    input  wire        s_axis_tlast,
    output wire [23:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tuser,
    output wire        m_axis_tlast,
    output reg  [31:0] frame_count,
    output reg  [31:0] bright_count_last,
    output reg  [31:0] malformed_count,
    output reg         detected_last,
    output wire [31:0] bbox_x_pair,
    output wire [31:0] bbox_y_pair
);
    localparam integer XW = (WIDTH < 2) ? 1 : $clog2(WIDTH + 1);
    localparam integer YW = (HEIGHT < 2) ? 1 : $clog2(HEIGHT + 1);
    localparam [9:0] XMAX = (WIDTH > 1023) ? 10'd1023 : WIDTH-1;
    localparam [8:0] YMAX = (HEIGHT > 511) ? 9'd511 : HEIGHT-1;

    reg [XW-1:0] x;
    reg [YW-1:0] y;
    reg in_frame;
    reg [31:0] bright_accum;
    reg [9:0] work_min_x, work_max_x;
    reg [8:0] work_min_y, work_max_y;
    reg [9:0] last_min_x, last_max_x;
    reg [8:0] last_min_y, last_max_y;

    wire fire = s_axis_tvalid && s_axis_tready;
    wire [XW-1:0] px = s_axis_tuser ? {XW{1'b0}} : x;
    wire [YW-1:0] py = s_axis_tuser ? {YW{1'b0}} : y;
    wire [9:0] px10 = px;
    wire [8:0] py9 = py;
    wire [9:0] luma_sum = {2'b0, s_axis_tdata[23:16]} +
                          {1'b0, s_axis_tdata[15:8], 1'b0} +
                          {2'b0, s_axis_tdata[7:0]};
    wire [7:0] luma = luma_sum[9:2];
    wire in_roi = (px >= ROI_X0) && (px <= ROI_X1) &&
                  (py >= ROI_Y0) && (py <= ROI_Y1);
    wire hit = in_roi && (luma >= LUMA_THRESHOLD);

    wire [31:0] base_count = s_axis_tuser ? 32'd0 : bright_accum;
    wire [31:0] count_after_pixel = (hit && base_count != 32'hFFFFFFFF) ?
                                    base_count + 1'b1 : base_count;
    wire [9:0] base_min_x = s_axis_tuser ? XMAX : work_min_x;
    wire [9:0] base_max_x = s_axis_tuser ? 10'd0 : work_max_x;
    wire [8:0] base_min_y = s_axis_tuser ? YMAX : work_min_y;
    wire [8:0] base_max_y = s_axis_tuser ? 9'd0 : work_max_y;
    wire [9:0] count_min_x = hit ? ((px10 < base_min_x) ? px10 : base_min_x) : base_min_x;
    wire [9:0] count_max_x = hit ? ((px10 > base_max_x) ? px10 : base_max_x) : base_max_x;
    wire [8:0] count_min_y = hit ? ((py9 < base_min_y) ? py9 : base_min_y) : base_min_y;
    wire [8:0] count_max_y = hit ? ((py9 > base_max_y) ? py9 : base_max_y) : base_max_y;

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tuser = s_axis_tuser;
    assign m_axis_tlast = s_axis_tlast;
    assign bbox_x_pair = {11'd0, detected_last, last_max_x, last_min_x};
    assign bbox_y_pair = {14'd0, last_max_y, last_min_y};

    always @(posedge aclk) begin
        if (!aresetn) begin
            x <= 0;
            y <= 0;
            in_frame <= 0;
            bright_accum <= 0;
            work_min_x <= XMAX;
            work_max_x <= 0;
            work_min_y <= YMAX;
            work_max_y <= 0;
            last_min_x <= XMAX;
            last_max_x <= 0;
            last_min_y <= YMAX;
            last_max_y <= 0;
            frame_count <= 0;
            bright_count_last <= 0;
            malformed_count <= 0;
            detected_last <= 0;
        end else if (fire) begin
            if (s_axis_tuser) begin
                if (in_frame) malformed_count <= malformed_count + 1'b1;
                in_frame <= !s_axis_tlast;
                bright_accum <= hit ? 1 : 0;
                work_min_x <= hit ? px10 : XMAX;
                work_max_x <= hit ? px10 : 0;
                work_min_y <= hit ? py9 : YMAX;
                work_max_y <= hit ? py9 : 0;
                if (s_axis_tlast) begin
                    malformed_count <= malformed_count + 1'b1;
                    x <= 0;
                    y <= 0;
                end else begin
                    x <= 1;
                    y <= 0;
                end
            end else if (in_frame) begin
                if (x >= WIDTH || y >= HEIGHT) begin
                    malformed_count <= malformed_count + 1'b1;
                    in_frame <= 0;
                    x <= 0;
                    y <= 0;
                    bright_accum <= 0;
                end else begin
                    bright_accum <= count_after_pixel;
                    work_min_x <= count_min_x;
                    work_max_x <= count_max_x;
                    work_min_y <= count_min_y;
                    work_max_y <= count_max_y;
                    if (s_axis_tlast) begin
                        if (x != WIDTH-1) begin
                            malformed_count <= malformed_count + 1'b1;
                            in_frame <= 0;
                            x <= 0;
                            y <= 0;
                        end else if (y == HEIGHT-1) begin
                            frame_count <= frame_count + 1'b1;
                            bright_count_last <= count_after_pixel;
                            detected_last <= (count_after_pixel != 0);
                            last_min_x <= count_min_x;
                            last_max_x <= count_max_x;
                            last_min_y <= count_min_y;
                            last_max_y <= count_max_y;
                            in_frame <= 0;
                            x <= 0;
                            y <= 0;
                            bright_accum <= 0;
                            work_min_x <= XMAX;
                            work_max_x <= 0;
                            work_min_y <= YMAX;
                            work_max_y <= 0;
                        end else begin
                            x <= 0;
                            y <= y + 1'b1;
                        end
                    end else if (x == WIDTH-1) begin
                        malformed_count <= malformed_count + 1'b1;
                        in_frame <= 0;
                        x <= 0;
                        y <= 0;
                    end else begin
                        x <= x + 1'b1;
                    end
                end
            end else begin
                malformed_count <= malformed_count + 1'b1;
            end
        end
    end
endmodule
