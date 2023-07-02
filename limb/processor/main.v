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
  wire [3:0] opcode = instruction[25:21];
  reg [3:0] alu_opcode;
  reg [3:0] alu_destination;
  reg [31:0] alu_x;
  reg [31:0] alu_y;
  wire [31:0] alu_z;
  arithmetic_logic_unit alu(
    .do_execute(do_execute),
    .opcode(alu_opcode),
    .cpsr(cpsr),
    .x(alu_x),
    .y(alu_y),
    .z(alu_z));
  reg [31:0] r [0:30];
  reg [31:0] cpsr;
  reg do_execute;
  reg [2:0] do_writeback;
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
      4'b0000: begin // eq
        if (cpsr[30]) begin
          do_execute <= 1;
        end
      end
      4'b0001: begin // ne
        if (!cpsr[30]) begin
          do_execute <= 1;
        end
      end
      4'b0010: begin // cs
        if (cpsr[29]) begin
          do_execute <= 1;
        end
      end
      4'b0011: begin // cc
        if (!cpsr[29]) begin
          do_execute <= 1;
        end
      end
      4'b0100: begin // mi
        if (cpsr[31]) begin
          do_execute <= 1;
        end
      end
      4'b0101: begin // pl
        if (!cpsr[31]) begin
          do_execute <= 1;
        end
      end
      4'b0110: begin // vs
        if (cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b0111: begin // vc
        if (!cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1000: begin // hi
        if (cpsr[29] || !cpsr[30]) begin
          do_execute <= 1;
        end
      end
      4'b1001: begin // ls
        if (!cpsr[29] || cpsr[30]) begin
          do_execute <= 1;
        end
      end
      4'b1010: begin // ge
        if (cpsr[31] == cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1011: begin // lt
        if (cpsr[31] != cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1100: begin // gt
        if (!cpsr[28] || cpsr[31] == cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1101: begin // le
        if (cpsr[28] || cpsr[31] != cpsr[28]) begin
          do_execute <= 1;
        end
      end
      4'b1110: begin // al
        do_execute <= 1;
      end
    endcase
    alu_opcode <= opcode;
    case (opcode)
      4'b1101: begin // mov
        alu_destination <= rd;
        alu_x <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b1101: begin // mvn
        alu_destination <= rd;
        alu_x <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b0100: begin // add
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b0101: begin // adc
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b0010: begin // sub
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b0110: begin // sbc
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b0011: begin // rsb
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b0111: begin // rsc
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b1010: begin // cmp
        alu_x <= r[rd];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 2;
      end
      4'b1011: begin // cmn
        alu_x <= r[rd];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 2;
      end
      4'b1000: begin // tst
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 2;
      end
      4'b1001: begin // teq
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 2;
      end
      4'b0000: begin // and
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b0001: begin // eor
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b1100: begin // orr
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
      4'b1110: begin // bic
        alu_destination <= rd;
        alu_x <= r[rn];
        alu_y <= !oprnd2_type ? r[oprnd2] : oprnd2;
        do_writeback <= 1;
      end
    endcase
    if (do_writeback) begin
      source <= alu_z;
      destination <= alu_destination;
      case (do_writeback)
        1: begin
          r[destination] <= source;
        end
        2: begin
          cpsr <= source;
        end
      endcase
    end
    r[15] <= r[15] + 1;
  end
endmodule

module arithmetic_logic_unit(
  do_execute,
  opcode,
  cpsr,
  x,
  y,
  z);
  input do_execute;
  input [3:0] opcode;
  input [31:0] cpsr;
  input [31:0] x;
  input [31:0] y;
  output reg [31:0] z;
  reg [31:0] r [3:0];

  always @ (*) begin
    if (do_execute) begin
      case (opcode)
        4'b1101: begin // mov
          z = x;
        end
        4'b1111: begin // mvn
          z = !x;
        end
        4'b0100: begin // add
          z = x + y;
        end
        4'b0101: begin // adc
          z = x + y + cpsr[29];
        end
        4'b0010: begin // sub
          z = x - y;
        end
        4'b0110: begin // sbc
          z = x - y - cpsr[29];
        end
        4'b0011: begin // rsb
          z = y - x;
        end
        4'b0111: begin // rsc
          z = y - x - cpsr[29];
        end
        4'b1010: begin // cmp
          r[0] = x + ~y + 1;
          r[1] = $signed(x) + $signed(~y) + 1;
          z[31] = r[0][31];
          z[30] = !r[0];
          z[29] = r[0][30:0] != r[0];
          z[28] = $signed(r[0][30:0]) != r[1];
          z[27:0] = cpsr[27:0];
        end
        4'b1011: begin // cmn
          r[0] = x + y + 1;
          r[1] = $signed(x) + $signed(y) + 1;
          z[31] = r[0][31];
          z[30] = !r[0];
          z[29] = r[0][30:0] != r[0];
          z[28] = $signed(r[0][30:0]) != r[1];
          z[27:0] = cpsr[27:0];
        end
        4'b1000: begin // tst
          r[0] = x & y;
          z[31] = r[0][31];
          z[30] = !r[0];
          z[29:0] = cpsr[29:0];
        end
        4'b1001: begin // teq
          r[0] = x ^ y;
          z[31] = r[0][31];
          z[30] = !r[0];
          z[29:0] = cpsr[29:0];
        end
        4'b0000: begin // and
          z = x & y;
        end
        4'b0001: begin // eor
          z = x ^ y;
        end
        4'b1100: begin // orr
          z = x | y;
        end
        4'b1110: begin // bic
          z = x & ~y;
        end
      endcase
    end
  end
endmodule
