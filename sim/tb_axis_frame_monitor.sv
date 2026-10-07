`timescale 1ns/1ps
module tb_axis_frame_monitor;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rstn = 0, valid = 0, ready = 1, user = 0, last = 0;
    reg [7:0] data = 0;
    wire sready, mvalid, muser, mlast;
    wire [7:0] mdata;
    wire [31:0] frames, malformed, edges, stalls;
    axis_frame_monitor #(.WIDTH(4), .HEIGHT(2), .EDGE_THRESHOLD(20)) dut (
      .aclk(clk), .aresetn(rstn), .s_axis_tdata(data),
      .s_axis_tvalid(valid), .s_axis_tready(sready),
      .s_axis_tuser(user), .s_axis_tlast(last),
      .m_axis_tdata(mdata), .m_axis_tvalid(mvalid),
      .m_axis_tready(ready), .m_axis_tuser(muser), .m_axis_tlast(mlast),
      .frame_count(frames), .malformed_count(malformed),
      .edge_count_last(edges), .stall_cycles(stalls));
    task beat(input [7:0] d, input u, input l);
      begin
        @(negedge clk); data=d; user=u; last=l; valid=1;
        @(posedge clk); #1;
        if (!mvalid || mdata !== d || muser !== u || mlast !== l)
          $fatal(1, "pass-through mismatch");
        @(negedge clk); valid=0; user=0; last=0;
      end
    endtask
    initial begin
      repeat (3) @(negedge clk); rstn=1;
      beat(8'd0,1,0); beat(8'd30,0,0); beat(8'd35,0,0); beat(8'd70,0,1);
      beat(8'd2,0,0); beat(8'd40,0,0); beat(8'd45,0,0); beat(8'd90,0,1);
      if (frames !== 1 || malformed !== 0 || edges !== 4)
        $fatal(1,"frame/edge mismatch frames=%d malformed=%d edges=%d",frames,malformed,edges);
      beat(8'd0,1,0); beat(8'd1,0,1); // short line
      if (malformed !== 1) $fatal(1,"short line not detected");
      beat(8'd4,1,0); // incomplete frame
      beat(8'd5,1,0); // new SOF counts malformed
      if (malformed !== 2) $fatal(1,"truncated frame not detected");
      @(negedge clk); data=8'd9; user=0; last=0; valid=1; ready=0;
      repeat (3) @(posedge clk);
      #1; if (stalls !== 3 || sready !== 0) $fatal(1,"stall count incorrect");
      @(negedge clk); valid=0;
      $display("PASS axis_frame_monitor frames=%d malformed=%d stalls=%d",frames,malformed,stalls);
      $finish;
    end
endmodule
