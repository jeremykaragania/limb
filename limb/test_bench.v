`include "processor.v"

module test_bench;
  reg clk;

  wire [31:0] addr_w;
  wire [31:0] wdata_w;
  wire [31:0] rdata_w;
  wire abort;
  wire write_w;
  wire size_w;
  wire [1:0] prot_w;
  wire [1:0] trans_w;

  processor p(
    .clk(clk),
    .n_reset(n_reset),

    .addr(addr_w),
    .wdata(wdata_w),
    .rdata(rdata_w),
    .abort(abort_w),
    .write(write_w),
    .size(size_w),
    .prot(prot_w),
    .trans(trans_w));

  memory_controller mc (
    .clk(clk),

    .addr(addr_w),
    .wdata(wdata_w),
    .rdata(rdata_w),
    .abort(abort_w),
    .write(write_w),
    .size(size_w),
    .prot(prot_w),
    .trans(trans_w));

  initial begin
    $monitor("%d\t%d\t%d\t%d\t%d", clk, p.opcode_w, p.a_w, p.b_w, p.result_w);

    $dumpfile("dump.vcd");
    $dumpvars(0, test_bench);

    clk = 1'b0;
    #64 $finish;
  end

  always begin
    #1 clk <= !clk;
  end
endmodule
