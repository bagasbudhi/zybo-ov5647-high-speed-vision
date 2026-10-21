`timescale 1ns/1ps
module tb_axis_bayer_vision;
    localparam integer W = 4;
    localparam integer H = 4;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rstn = 0;
    reg valid = 0;
    reg ready = 1;
    reg user = 0;
    reg last = 0;
    reg [7:0] bayer [0:3];
    wire [3:0] sready, mvalid, muser, mlast;
    wire [23:0] rgb [0:3];

    genvar p;
    generate for (p=0; p<4; p=p+1) begin : g_demosaic
        axis_bayer_demosaic #(.WIDTH(W), .BAYER_PHASE(p)) dut (
            .aclk(clk), .aresetn(rstn), .s_axis_tdata(bayer[p]),
            .s_axis_tvalid(valid), .s_axis_tready(sready[p]),
            .s_axis_tuser(user), .s_axis_tlast(last), .m_axis_tdata(rgb[p]),
            .m_axis_tvalid(mvalid[p]), .m_axis_tready(ready),
            .m_axis_tuser(muser[p]), .m_axis_tlast(mlast[p]));
    end endgenerate

    function automatic [1:0] cfa_color;
        input integer phase;
        input integer xx;
        input integer yy;
        begin
            case (phase)
                0: cfa_color = ((yy&1)==0) ? (((xx&1)==0)?2:1) : (((xx&1)==0)?1:0);
                1: cfa_color = ((yy&1)==0) ? (((xx&1)==0)?1:2) : (((xx&1)==0)?0:1);
                2: cfa_color = ((yy&1)==0) ? (((xx&1)==0)?1:0) : (((xx&1)==0)?2:1);
                default: cfa_color = ((yy&1)==0) ? (((xx&1)==0)?0:1) : (((xx&1)==0)?1:2);
            endcase
        end
    endfunction

    task send_cfa_pixel(input integer xx, input integer yy);
        integer k;
        reg [7:0] sample;
        begin
            @(negedge clk);
            for (k=0;k<4;k=k+1) begin
                case (cfa_color(k,xx,yy))
                    0: sample=8'd200;
                    1: sample=8'd100;
                    default: sample=8'd20;
                endcase
                bayer[k]=sample;
            end
            user=(xx==0 && yy==0);
            last=(xx==W-1);
            valid=1;
            #1;
            if (mvalid !== 4'b1111 || sready !== 4'b1111)
                $fatal(1,"demosaic stream handshake mismatch");
            if (xx>=1 && yy>=1) begin
                for (k=0;k<4;k=k+1)
                    if (rgb[k] !== {8'd200,8'd100,8'd20})
                        $fatal(1,"phase %0d pixel (%0d,%0d) got %06x",k,xx,yy,rgb[k]);
            end
            @(posedge clk);
            #1;
            if (muser !== {4{xx==0 && yy==0}} || mlast !== {4{xx==W-1}})
                $fatal(1,"demosaic marker mismatch");
            @(negedge clk); valid=0; user=0; last=0;
        end
    endtask

    reg det_valid=0, det_ready=1, det_user=0, det_last=0;
    reg [23:0] det_data=0;
    wire det_sready, det_mvalid, det_muser, det_mlast, detected;
    wire [23:0] det_out;
    wire [31:0] frame_count, bright_count, malformed;
    wire [31:0] bbox_x, bbox_y;
    axis_bright_roi_detector #(.WIDTH(W), .HEIGHT(3), .ROI_X0(1), .ROI_Y0(1),
        .ROI_X1(2), .ROI_Y1(2), .LUMA_THRESHOLD(80)) detector (
        .aclk(clk), .aresetn(rstn), .s_axis_tdata(det_data),
        .s_axis_tvalid(det_valid), .s_axis_tready(det_sready),
        .s_axis_tuser(det_user), .s_axis_tlast(det_last), .m_axis_tdata(det_out),
        .m_axis_tvalid(det_mvalid), .m_axis_tready(det_ready),
        .m_axis_tuser(det_muser), .m_axis_tlast(det_mlast),
        .frame_count(frame_count), .bright_count_last(bright_count),
        .malformed_count(malformed), .detected_last(detected),
        .bbox_x_pair(bbox_x), .bbox_y_pair(bbox_y));

    task detector_pixel(input integer xx, input integer yy, input [23:0] rgb_in);
        begin
            @(negedge clk);
            det_data=rgb_in;
            det_user=(xx==0 && yy==0);
            det_last=(xx==W-1);
            det_valid=1;
            #1;
            if (!det_mvalid || det_out !== rgb_in) $fatal(1,"detector pass-through mismatch");
            @(posedge clk); #1;
            @(negedge clk); det_valid=0; det_user=0; det_last=0;
        end
    endtask

    integer x,y;
    initial begin
        repeat (3) @(negedge clk); rstn=1;

        // Feed all four CFA phases with the same constant RGB scene.
        for (y=0;y<H;y=y+1)
            for (x=0;x<W;x=x+1)
                send_cfa_pixel(x,y);

        // Exercise output backpressure without advancing the demosaic state.
        @(negedge clk); ready=0; valid=1; user=0; last=0; bayer[0]=8'h31;
        bayer[1]=8'h31; bayer[2]=8'h31; bayer[3]=8'h31;
        repeat (2) begin
            @(posedge clk); #1;
            if (sready !== 0 || mvalid !== 4'b1111) $fatal(1,"demosaic stall behavior");
        end
        @(negedge clk); ready=1;
        @(posedge clk); #1;
        @(negedge clk); valid=0; user=0; last=0;

        // One valid 4x3 frame: two bright pixels inside the ROI; one outside.
        for (y=0;y<3;y=y+1)
            for (x=0;x<W;x=x+1) begin
                if ((x==1 && y==1) || (x==2 && y==2))
                    detector_pixel(x,y,24'h646464);
                else if (x==0 && y==0)
                    detector_pixel(x,y,24'hFFFFFF);
                else
                    detector_pixel(x,y,24'h202020);
            end
        if (frame_count !== 1 || bright_count !== 2 || !detected)
            $fatal(1,"ROI count/frame mismatch frame=%0d count=%0d detected=%b",frame_count,bright_count,detected);
        if (bbox_x[9:0] !== 10'd1 || bbox_x[19:10] !== 10'd2 ||
            bbox_y[8:0] !== 9'd1 || bbox_y[17:9] !== 9'd2)
            $fatal(1,"ROI box mismatch x=%h y=%h",bbox_x,bbox_y);

        @(negedge clk); det_valid=1; det_user=1; det_last=1; det_data=0;
        @(posedge clk); #1;
        @(negedge clk); det_valid=0; det_user=0; det_last=0;
        if (malformed !== 1) $fatal(1,"malformed one-line frame not counted");

        $display("PASS Bayer demosaic (4 phases), AXI backpressure, ROI count and bounding box");
        $finish;
    end
endmodule
