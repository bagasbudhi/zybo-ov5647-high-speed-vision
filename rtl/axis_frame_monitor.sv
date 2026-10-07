`timescale 1ns/1ps
// One 8-bit sample per beat. TUSER[0] marks SOF; TLAST marks EOL.
// The output is a zero-latency AXI4-Stream pass-through. Counters update only
// for accepted beats. A frame is complete at EOL of line HEIGHT-1.
module axis_frame_monitor #(
    parameter integer WIDTH = 640,
    parameter integer HEIGHT = 480,
    parameter integer EDGE_THRESHOLD = 24
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [7:0]  s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tuser,
    input  wire        s_axis_tlast,
    output wire [7:0]  m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tuser,
    output wire        m_axis_tlast,
    output reg  [31:0] frame_count,
    output reg  [31:0] malformed_count,
    output reg  [31:0] edge_count_last,
    output reg  [31:0] stall_cycles
);
    localparam integer XW = (WIDTH < 2) ? 1 : $clog2(WIDTH + 1);
    localparam integer YW = (HEIGHT < 2) ? 1 : $clog2(HEIGHT + 1);
    reg [XW-1:0] x;
    reg [YW-1:0] y;
    reg [7:0] previous_pixel;
    reg [31:0] edge_accum;
    reg in_frame;
    wire fire = s_axis_tvalid && s_axis_tready;
    wire [7:0] delta = (s_axis_tdata >= previous_pixel) ?
                       (s_axis_tdata - previous_pixel) :
                       (previous_pixel - s_axis_tdata);
    wire edge_hit = (x != 0) && (delta >= EDGE_THRESHOLD);

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tuser = s_axis_tuser;
    assign m_axis_tlast = s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            x <= 0;
            y <= 0;
            previous_pixel <= 0;
            edge_accum <= 0;
            in_frame <= 0;
            frame_count <= 0;
            malformed_count <= 0;
            edge_count_last <= 0;
            stall_cycles <= 0;
        end else begin
            if (s_axis_tvalid && !m_axis_tready)
                stall_cycles <= stall_cycles + 1'b1;
            if (fire) begin
                previous_pixel <= s_axis_tdata;
                if (s_axis_tuser) begin
                    // A new SOF terminates any incomplete previous frame.
                    if (in_frame) malformed_count <= malformed_count + 1'b1;
                    in_frame <= 1'b1;
                    x <= 1;
                    y <= 0;
                    edge_accum <= 0;
                    if (s_axis_tlast || WIDTH == 1) begin
                        // One-pixel lines are intentionally unsupported.
                        malformed_count <= malformed_count + 1'b1;
                        in_frame <= 1'b0;
                        x <= 0;
                    end
                end else if (in_frame) begin
                    if (s_axis_tlast) begin
                        if (x != WIDTH-1) begin
                            malformed_count <= malformed_count + 1'b1;
                            in_frame <= 1'b0;
                            x <= 0;
                            y <= 0;
                        end else if (y == HEIGHT-1) begin
                            frame_count <= frame_count + 1'b1;
                            edge_count_last <= edge_accum + edge_hit;
                            in_frame <= 1'b0;
                            x <= 0;
                            y <= 0;
                        end else begin
                            edge_accum <= edge_accum + edge_hit;
                            y <= y + 1'b1;
                            x <= 0;
                        end
                    end else if (x >= WIDTH) begin
                        malformed_count <= malformed_count + 1'b1;
                        in_frame <= 1'b0;
                        x <= 0;
                        y <= 0;
                    end else begin
                        edge_accum <= edge_accum + edge_hit;
                        x <= x + 1'b1;
                    end
                end else begin
                    // Ignore payload outside a frame, but count it.
                    malformed_count <= malformed_count + 1'b1;
                end
            end
        end
    end
endmodule
