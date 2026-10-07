`timescale 1ns/1ps
// Stream block designed to sit after CSI RX video_out and before a video DMA.
module axis_vision_pipeline #(
    parameter integer WIDTH = 640,
    parameter integer HEIGHT = 480,
    parameter integer EDGE_THRESHOLD = 24
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [15:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tuser,
    input  wire        s_axis_tlast,
    output wire [7:0]  m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tuser,
    output wire        m_axis_tlast,
    output wire [31:0] frame_count,
    output wire [31:0] malformed_count,
    output wire [31:0] edge_count_last,
    output wire [31:0] stall_cycles
);
    wire [7:0] pixel8;
    wire valid8, ready8, user8, last8;
    axis_raw10_to_bayer8 convert (
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready), .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast), .m_axis_tdata(pixel8),
        .m_axis_tvalid(valid8), .m_axis_tready(ready8),
        .m_axis_tuser(user8), .m_axis_tlast(last8));
    axis_frame_monitor #(.WIDTH(WIDTH), .HEIGHT(HEIGHT),
                         .EDGE_THRESHOLD(EDGE_THRESHOLD)) monitor (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(pixel8), .s_axis_tvalid(valid8),
        .s_axis_tready(ready8), .s_axis_tuser(user8),
        .s_axis_tlast(last8), .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready),
        .m_axis_tuser(m_axis_tuser), .m_axis_tlast(m_axis_tlast),
        .frame_count(frame_count), .malformed_count(malformed_count),
        .edge_count_last(edge_count_last), .stall_cycles(stall_cycles));
endmodule
