`include "main.v"

module test_bench;
  reg clk;
  central_processing_unit cpu(.clk(clk));

  initial begin
    $monitor("%d\t%d\t%d\t%d\t%d\t%d", clk, cpu.cu.id_opcode, cpu.cu.id_alu_a, cpu.cu.id_alu_b, cpu.cu.id_alu_c, cpu.cu.id_alu_d);
    clk = 0;
    #64 $finish;
  end

  always begin
    #1 clk <= !clk;
  end
endmodule
