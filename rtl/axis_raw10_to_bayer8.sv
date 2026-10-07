`timescale 1ns/1ps
// Adapter for the generated CSI RX video_out interface (one 16-bit RAW10
// sample per transfer). This assumes valid pixel bits are [9:0], as required
// to be verified against a captured sensor test pattern during bring-up.
module axis_raw10_to_bayer8 (
    input  wire [15:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tuser,
    input  wire        s_axis_tlast,
    output wire [7:0]  m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tuser,
    output wire        m_axis_tlast
);
    assign m_axis_tdata = s_axis_tdata[9:2];
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tuser = s_axis_tuser;
    assign m_axis_tlast = s_axis_tlast;
endmodule
