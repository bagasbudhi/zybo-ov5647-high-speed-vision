`timescale 1ns/1ps
// Causal 3-sample Bayer interpolator for a one-pixel-per-beat AXI4-Stream.
// BAYER_PHASE: 0=BGGR, 1=GBRG, 2=GRBG, 3=RGGB (top-left pixel first).
// The current sample is combined with its left, upper, and upper-left
// neighbors. This is intentionally a low-resource causal approximation of
// bilinear demosaicing: no future sample or additional stream latency is
// required. At image borders, unavailable colors fall back to the current
// sample. One 8-bit line buffer is used; stream markers pass through unchanged.
module axis_bayer_demosaic #(
    parameter integer WIDTH = 640,
    parameter integer BAYER_PHASE = 0
) (
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
    localparam integer XW = (WIDTH < 2) ? 1 : $clog2(WIDTH + 1);

    // CFA color encoding: 0=R, 1=G, 2=B.
    function automatic [1:0] cfa_color;
        input x_parity;
        input y_parity;
        begin
            case (BAYER_PHASE)
                0: cfa_color = (!y_parity && !x_parity) ? 2 :
                               (!y_parity &&  x_parity) ? 1 :
                               ( y_parity && !x_parity) ? 1 : 0; // BGGR
                1: cfa_color = (!y_parity && !x_parity) ? 1 :
                               (!y_parity &&  x_parity) ? 2 :
                               ( y_parity && !x_parity) ? 0 : 1; // GBRG
                2: cfa_color = (!y_parity && !x_parity) ? 1 :
                               (!y_parity &&  x_parity) ? 0 :
                               ( y_parity && !x_parity) ? 2 : 1; // GRBG
                default: cfa_color = (!y_parity && !x_parity) ? 0 :
                                     (!y_parity &&  x_parity) ? 1 :
                                     ( y_parity && !x_parity) ? 1 : 2; // RGGB
            endcase
        end
    endfunction

    reg [7:0] linebuf [0:WIDTH-1];
    reg [7:0] left_pixel;
    reg [7:0] upper_left;
    reg [XW-1:0] x;
    reg y_parity;
    reg has_previous_row;

    wire fire = s_axis_tvalid && s_axis_tready;
    wire [XW-1:0] px = s_axis_tuser ? {XW{1'b0}} : x;
    wire py = s_axis_tuser ? 1'b0 : y_parity;
    wire row_valid = !s_axis_tuser && has_previous_row;
    wire [7:0] upper_pixel = (row_valid && (px < WIDTH)) ? linebuf[px] : 8'd0;
    wire [1:0] current_color = cfa_color(px[0], py);

    reg [10:0] sum_r, sum_g, sum_b;
    reg [1:0] count_r, count_g, count_b;
    reg [7:0] red, green, blue;
    reg [1:0] neighbor_color;

    always @* begin
        sum_r = 0; sum_g = 0; sum_b = 0;
        count_r = 0; count_g = 0; count_b = 0;

        if (current_color == 0) begin sum_r = s_axis_tdata; count_r = 1; end
        if (current_color == 1) begin sum_g = s_axis_tdata; count_g = 1; end
        if (current_color == 2) begin sum_b = s_axis_tdata; count_b = 1; end

        if (px != 0) begin
            neighbor_color = cfa_color(px[0] ^ 1'b1, py);
            if (neighbor_color == 0) begin sum_r = sum_r + left_pixel; count_r = count_r + 1'b1; end
            if (neighbor_color == 1) begin sum_g = sum_g + left_pixel; count_g = count_g + 1'b1; end
            if (neighbor_color == 2) begin sum_b = sum_b + left_pixel; count_b = count_b + 1'b1; end
        end
        if (row_valid) begin
            neighbor_color = cfa_color(px[0], ~py);
            if (neighbor_color == 0) begin sum_r = sum_r + upper_pixel; count_r = count_r + 1'b1; end
            if (neighbor_color == 1) begin sum_g = sum_g + upper_pixel; count_g = count_g + 1'b1; end
            if (neighbor_color == 2) begin sum_b = sum_b + upper_pixel; count_b = count_b + 1'b1; end
        end
        if (px != 0 && row_valid) begin
            neighbor_color = cfa_color(px[0] ^ 1'b1, ~py);
            if (neighbor_color == 0) begin sum_r = sum_r + upper_left; count_r = count_r + 1'b1; end
            if (neighbor_color == 1) begin sum_g = sum_g + upper_left; count_g = count_g + 1'b1; end
            if (neighbor_color == 2) begin sum_b = sum_b + upper_left; count_b = count_b + 1'b1; end
        end

        red = (count_r == 0) ? s_axis_tdata :
              (count_r == 1) ? sum_r[7:0] : ((sum_r + 1'b1) >> 1);
        green = (count_g == 0) ? s_axis_tdata :
                (count_g == 1) ? sum_g[7:0] : ((sum_g + 1'b1) >> 1);
        blue = (count_b == 0) ? s_axis_tdata :
               (count_b == 1) ? sum_b[7:0] : ((sum_b + 1'b1) >> 1);
    end

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata = {red, green, blue};
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tuser = s_axis_tuser;
    assign m_axis_tlast = s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            x <= 0;
            y_parity <= 0;
            has_previous_row <= 0;
            left_pixel <= 0;
            upper_left <= 0;
        end else if (fire) begin
            if (px < WIDTH) begin
                if (row_valid) upper_left <= upper_pixel;
                else upper_left <= 0;
                linebuf[px] <= s_axis_tdata;
            end
            if (px == 0) left_pixel <= s_axis_tdata;
            else left_pixel <= s_axis_tdata;

            if (s_axis_tuser) begin
                has_previous_row <= 0;
                if (s_axis_tlast) begin x <= 0; y_parity <= 1'b1; end
                else begin x <= 1; y_parity <= 1'b0; end
            end else if (s_axis_tlast) begin
                x <= 0;
                y_parity <= ~y_parity;
                has_previous_row <= 1;
                upper_left <= 0;
            end else if (px < WIDTH) begin
                x <= px + 1'b1;
            end
        end
    end
endmodule
