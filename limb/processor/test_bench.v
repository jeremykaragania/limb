`include "main.v"

module test_bench;
  reg clk;

  processor p(
    .clk(clk),
    .n_reset(n_reset));

  memory_controller mc (
    .clk(clk),
    .addr(p.addr_reg),
    .wdata(p.wdata),
    .rdata(p.rdata),
    .abort(p.abort),
    .write(p.write_reg),
    .size(p.size_reg),
    .prot(p.prot_reg),
    .trans(p.trans_reg));

  arithmetic_logic_unit alu (
    .clk(clk),
    .a(p.a),
    .b(p.b),
    .cpsr(p.cpsr),
    .opcode(p.opcode),
    .result(p.result));

  multiplier m(
    .clk(clk),
    .a(p.a),
    .b(p.b),
    .c(p.c),
    .d(p.d),
    .type(p.type),
    .result(p.m_result));

  initial begin
    $monitor("%d\t%d\t%d\t%d\t%d", clk, p.opcode, p.a, p.b, p.result);
    clk = 0;
    #64 $finish;
  end

  always begin
    #1 clk <= !clk;
  end
endmodule
