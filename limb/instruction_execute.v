`ifndef INSTRUCTION_EXECUTE_V
`define INSTRUCTION_EXECUTE_V

module instruction_execute (
  input clk,
  input rst,

  input exec_i,

  input [3:0] dest_i,

  input write_dest_do_i,
  input write_dest_m_i,
  input write_cpsr_i,

  input [31:0] do_cycle_i,
  input [31:0] m_ma_cycle_i,

  input [31:0] a_i,
  input [31:0] b_i,
  input [31:0] c_i,
  input [31:0] d_i,
  input [3:0] opcode_i,
  input [2:0] type_i,

  input [31:0] cpsr_i,

  output reg [3:0] dest_o,

  output reg write_dest_do_o,
  output reg write_dest_m_o,
  output reg write_cpsr_o,

  output reg write_o,
  output reg [1:0] trans_o,

  output [31:0] result_o,
  output [63:0] m_result_o);

  arithmetic_logic_unit alu (
    .clk(clk),
    .rst(rst),
    .a(a_i),
    .b(b_i),
    .cpsr(cpsr_i),
    .opcode(opcode_i),
    .result(result_o));

  multiplier m(
    .clk(clk),
    .rst(rst),
    .a(a_i),
    .b(b_i),
    .c(c_i),
    .d(d_i),
    .type(type_i),
    .result(m_result_o));

  always @ (posedge clk) begin
    if (rst) begin
      dest_o <= 4'b0;

      write_dest_do_o <= 1'b0;
      write_dest_m_o <= 1'b0;
      write_cpsr_o <= 1'b0;

      write_o <= 1'b0;
      trans_o <= 2'b0;
    end
    if (exec_i) begin
      write_dest_do_o <= write_dest_do_i;
      write_dest_m_o <= write_dest_m_i;
      write_cpsr_o <= write_cpsr_i;

      if (do_cycle_i) begin // Data operation.
        trans_o <= 2'b11;
        dest_o <= dest_i;
      end
      else if (m_ma_cycle_i) begin // Multiply or multiply accumulate.
        trans_o <= 2'b11;
        dest_o <= dest_i;
      end
      else begin // No operation.
        trans_o <= 2'b11;
      end
    end
    else begin
      trans_o <= 2'b11;
      write_o <= 1'b0;
    end
  end
endmodule

`endif
