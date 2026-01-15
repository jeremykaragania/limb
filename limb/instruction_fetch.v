`ifndef INSTRUCTION_FETCH_V
`define INSTRUCTION_FETCH_V

module instruction_fetch (
  input clk,
  input rst,
  input write_pc_i,
  input [31:0] pc_i,
  input [31:0] instr_i,

  output reg [31:0] pc_o,
  output reg [31:0] instr_o);

  reg [31:0] pc_r;

  initial begin
    pc_r = 32'b0;
  end

  always @ (posedge clk) begin
    if (rst) begin
      pc_o <= 32'b0;
      instr_o <= 32'b0;
    end
    if (write_pc_i) begin
      pc_r <= pc_i;
    end
    else begin
      pc_r <= pc_r + 32'd4;
      pc_o <= pc_r;
      instr_o <= instr_i;
    end
  end
endmodule

`endif
