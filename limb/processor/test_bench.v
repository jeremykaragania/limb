`include "processor.v"

module test_bench;
  reg clk;
  wire [31:0] addr_w;

  processor p(
    .clk(clk),
    .n_reset(n_reset),
    .addr(addr_w));

  memory_controller mc (
    .clk(clk),
    .addr(addr_w),
    .wdata(p.wdata),
    .rdata(p.rdata),
    .write(p.write_reg),
    .trans(p.trans_reg));

  initial begin
    $monitor("%d\t%d\t%d\t%d\t%d", clk, p.opcode_w, p.a_w, p.b_w, p.result_w);
    clk = 1'b0;
    #64 $finish;
  end

  always begin
    #1 clk <= !clk;
  end
endmodule
