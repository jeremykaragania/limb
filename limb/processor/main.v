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
  reg [31:0] mem [0:8191];

  initial begin
    $readmemh("boot.txt", mem);
  end

  always @ (posedge clk) begin
    if (rw) begin
      mem[a] = din;
    end
    else begin
      dout = mem[a];
    end
  end
endmodule
