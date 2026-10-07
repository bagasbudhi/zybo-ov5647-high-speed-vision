`timescale 1ns / 1ps
// Expand one 8-bit luma sample into RGB888 while preserving AXI4-Stream video markers.
module axis_gray_to_rgb (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [7:0]  s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tuser,
    input  wire        s_axis_tlast,
    output wire [23:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tuser,
    output wire        m_axis_tlast
);
    assign m_axis_tdata  = {s_axis_tdata, s_axis_tdata, s_axis_tdata};
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tuser  = s_axis_tuser;
    assign m_axis_tlast  = s_axis_tlast;
endmodule
