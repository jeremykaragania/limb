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
  wire [3:0] cond = instruction[31:28];
  wire oprnd2_type = instruction[25];
  wire [3:0] rd = instruction[15:12];
  wire [3:0] rn = instruction[19:16];
  wire [11:0] oprnd2 = instruction[11:0];
  reg do_execute;
  wire [3:0] opcode = instruction[25:21];
  reg [31:0] alu_x;
  reg [31:0] alu_y;
  wire [31:0] alu_z;
  arithmetic_logic_unit alu(
    .do_execute(do_execute),
    .opcode(opcode),
    .x(alu_x),
    .y(alu_y),
    .z(alu_z)
    );
  reg [31:0] r [0:30];
  reg [31:0] cpsr;
  reg do_writeback;
  reg [31:0] source;
  reg [3:0] destination;

  initial begin
    r[15] = 0;
    cpsr = 0;
  end

  always @ (posedge clk) begin
    ram_a <= r[15];
    ram_rw <= 0;
    case (cond)
      4'b0000: begin
        if (cpsr[30]) begin
          do_execute <= 1;
        end
      end
      4'b0001: begin
        if (!cpsr[30]) begin
          do_execute <= 1;
        end
      end
      4'b0010: begin
        if (cpsr[29]) begin
          do_execute <= 1;
        end
      end
      4'b0011: begin
        if (!cpsr[29]) begin
          do_execute <= 1;
        end
      end
      4'b0100: begin
        if (cpsr[31]) begin
          do_execute <= 1;
        end
      end
      4'b0101: begin
        if (!cpsr[31]) begin
          do_execute <= 1;
        end
      end
      4'b0110: begin
        if (cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b0111: begin
        if (!cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1000: begin
        if (cpsr[29] || !cpsr[30]) begin
          do_execute <= 1;
        end
      end
      4'b1001: begin
        if (!cpsr[29] || cpsr[30]) begin
          do_execute <= 1;
        end
      end
      4'b1010: begin
        if (cpsr[31] == cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1011: begin
        if (cpsr[31] != cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1100: begin
        if (!cpsr[28] || cpsr[31] == cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1101: begin
        if (cpsr[28] || cpsr[31] != cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1110: begin
        do_execute <= 1;
      end
    endcase
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
  do_execute,
  opcode,
  x,
  y,
  z);
  input do_execute;
  input [3:0] opcode;
  input [31:0] x;
  input [31:0] y;
  output reg [31:0] z;

  always @ (*) begin
    if (do_execute) begin
      case (opcode)
        4'b1101: begin
          z = y;
        end
      endcase
    end
  end
endmodule
