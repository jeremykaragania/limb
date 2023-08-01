`include "main.v"

module test_bench;
  reg clk;
  central_processing_unit cpu(.clk(clk));

  initial begin
    $monitor("%d\t%d\t%d\t%d\t%d\t%d", clk, cpu.cu.alu_opcode, cpu.cu.alu_a, cpu.cu.alu_b, cpu.cu.alu_c, cpu.cu.alu_d);
    clk = 0;
    #64 $finish;
  end

  always begin
    #1 clk <= !clk;
  end
endmodule
