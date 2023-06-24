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

module control_unit(
  clk
  );
  input clk;
  reg [31:0] a;
  reg [31:0] din;
  wire [31:0] dout;
  reg rw;
  random_access_memory ram(.clk(clk), .a(a), .din(din), .dout(dout), .rw(rw));
  wire [3:0] opcode = dout[25:21];
  reg [31:0] r [0:30];

  initial begin
    r[15] = 0;
  end

  always @ (posedge clk) begin
    a <= r[15];
    r[15] <= r[15] + 1;
  end
endmodule
