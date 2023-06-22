module random_access_memory(
  clk,
  a,
  din,
  dout,
  rw);
  input clk;
  input [31:0] a;
  input [31:0] din;
  output reg [31:0] dout;
  input rw;
  reg [31:0] mem [0:128];

  always @ (posedge clk) begin
    if (rw) begin
      dout = mem[a];
    end
    else begin
      mem[a] = din;
    end
  end
endmodule
