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
      mem[a] <= din;
    end
    else begin
      dout <= mem[a];
    end
  end
endmodule

module control_unit(
  clk);
  input clk;
  reg [31:0] ram_a;
  reg [31:0] ram_din;
  wire [31:0] ram_dout;
  reg ram_rw;
  random_access_memory ram(
    .clk(clk),
    .a(ram_a),
    .din(ram_din),
    .dout(ram_dout),
    .rw(ram_rw));
  wire [31:0] instruction = ram_dout;
  reg [3:0] cond;
  reg oprnd2_type;
  reg [3:0] rd;
  reg [3:0] rn;
  reg [11:0] oprnd2;
  reg [3:0] opcode;
  reg [31:0] alu_x;
  reg [31:0] alu_y;
  wire [31:0] alu_z;
  arithmetic_logic_unit alu(
    .opcode(opcode),
    .x(alu_x),
    .y(alu_y),
    .z(alu_z)
    );
  reg [31:0] r [0:30];
  reg do_writeback;
  reg [31:0] source;
  reg [3:0] destination;

  initial begin
    r[15] = 0;
  end

  always @ (posedge clk) begin
    ram_a <= r[15];
    ram_rw <= 0;
    opcode <= instruction[25:21];
    cond <= instruction[31:28];
    oprnd2_type <= instruction[25];
    rd <= instruction[15:12];
    rn <= instruction[19:16];
    oprnd2 <= instruction[11:0];
    case (opcode)
      4'b1101: begin
        alu_x <= rd;
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
    endcase
    destination <= alu_x;
    source <= alu_z;
    if (do_writeback) begin
      r[destination] <= source;
    end
    r[15] <= r[15] + 1;
  end
endmodule

module arithmetic_logic_unit(
  opcode,
  x,
  y,
  z
);
  input [3:0] opcode;
  input [31:0] x;
  input [31:0] y;
  output reg [31:0] z;

  always @ (*) begin
    case (opcode)
      4'b1101: begin
        z = y;
      end
    endcase
  end
endmodule
