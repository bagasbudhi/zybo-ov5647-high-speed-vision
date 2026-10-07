`timescale 1ns/1ps
module tb_axis_vision_pipeline;
  reg clk=0; always #5 clk=~clk;
  reg rstn=0, valid=0, ready=1, user=0, last=0;
  reg [15:0] data=0;
  wire sready, mvalid, muser, mlast;
  wire [7:0] mdata;
  wire [31:0] frames, malformed, edges, stalls;
  axis_vision_pipeline #(.WIDTH(2),.HEIGHT(2),.EDGE_THRESHOLD(10)) dut (
    .aclk(clk),.aresetn(rstn),.s_axis_tdata(data),.s_axis_tvalid(valid),
    .s_axis_tready(sready),.s_axis_tuser(user),.s_axis_tlast(last),
    .m_axis_tdata(mdata),.m_axis_tvalid(mvalid),.m_axis_tready(ready),
    .m_axis_tuser(muser),.m_axis_tlast(mlast),.frame_count(frames),
    .malformed_count(malformed),.edge_count_last(edges),.stall_cycles(stalls));
  task beat(input [9:0] p,input u,input l);
    begin
      @(negedge clk); data={6'b0,p}; user=u; last=l; valid=1;
      #1; if (!mvalid || mdata !== p[9:2] || muser !== u || mlast !== l)
        $fatal(1,"RAW10 adapter mismatch");
      @(posedge clk); @(negedge clk); valid=0; user=0; last=0;
    end
  endtask
  initial begin
    repeat(3) @(negedge clk); rstn=1;
    beat(10'd0,1,0); beat(10'd80,0,1);
    beat(10'd4,0,0); beat(10'd84,0,1);
    if (frames !== 1 || malformed !== 0 || edges !== 2)
      $fatal(1,"pipeline counters mismatch");
    $display("PASS axis_vision_pipeline"); $finish;
  end
endmodule
