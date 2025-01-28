`ifndef WRITE_BACK_V
`define WRITE_BACK_V

module write_back (
  input clk,

  input [3:0] dest_i,

  input write_dest_do_i,
  input write_dest_m_i,
  input write_cpsr_i,

  input [31:0] result_i,
  input [63:0] m_result_i,

  output reg [5:0] rw_i_o,
  output reg [31:0] rw_o,
  output reg [31:0] cpsr_o);

  initial begin
    rw_i_o = 6'b0;
    rw_o = 32'b0;
    cpsr_o = 32'b0;
  end

  always @ (posedge clk) begin
    if (write_dest_do_i) begin
      rw_i_o <= dest_i;
      rw_o <= result_i;
    end
    else if (write_dest_m_i) begin
      rw_i_o <= dest_i;
      rw_o <= m_result_i;
    end
    else if (write_cpsr_i) begin
      cpsr_o <= result_i;
    end
  end
endmodule

`endif
