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
  wire [3:0] rn = instruction[19:16];
  wire [3:0] rd = instruction[15:12];
  wire [3:0] rs = instruction[11:8];
  wire [3:0] rm = instruction[3:0];
  wire [11:0] oprnd2 = instruction[11:0];
  wire [3:0] opcode = instruction[24:21];
  reg [3:0] alu_opcode;
  reg [3:0]  alu_destinations [1:0];
  reg [31:0] alu_a;
  reg [31:0] alu_b;
  reg [31:0] alu_c;
  reg [31:0] alu_d;
  wire [63:0] alu_result;
  arithmetic_logic_unit alu(
    .do_execute(do_execute),
    .do_mul(do_mul),
    .opcode(alu_opcode),
    .cpsr(cpsr),
    .a(alu_a),
    .b(alu_b),
    .c(alu_c),
    .d(alu_d),
    .result(alu_result));
  reg [31:0] r [0:30];
  reg [31:0] cpsr;
  reg do_execute;
  reg do_mul;
  reg [2:0] do_writeback;
  reg [63:0] source;
  reg [3:0] destinations [1:0];

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
    if (!instruction[25] && instruction[4]) begin
      do_mul <= 1;
      case (opcode)
        4'b0000: begin // mul
          alu_destinations[0] <= rn;
          alu_a <= r[rd];
          alu_b <= r[rs];
          do_writeback <= 1;
        end
        4'b0001: begin // mla
          alu_destinations[0] <= rn;
          alu_a <= r[rd];
          alu_b <= r[rs];
          alu_c <= r[rm];
          do_writeback <= 1;
        end
        4'b0100: begin // umull
          alu_destinations[0] <= rd;
          alu_destinations[1] <= rn;
          alu_a <= r[rm];
          alu_b <= r[rs];
          do_writeback <= 3;
        end
        4'b0101: begin // umlal
          alu_destinations[0] <= rd;
          alu_destinations[1] <= rn;
          alu_a <= r[rm];
          alu_b <= r[rs];
          alu_c <= r[rd];
          alu_d <= r[rn];
          do_writeback <= 3;
        end
        4'b0110: begin // smull
          alu_destinations[0] <= rd;
          alu_destinations[1] <= rn;
          alu_a <= r[rm];
          alu_b <= r[rs];
          do_writeback <= 3;
        end
        4'b0111: begin // smlal
          alu_destinations[0] <= rd;
          alu_destinations[1] <= rn;
          alu_a <= r[rm];
          alu_b <= r[rs];
          alu_c <= r[rd];
          alu_d <= r[rn];
          do_writeback <= 3;
        end
      endcase
    end
    else begin
      case (opcode)
        4'b1101: begin // mov
          alu_destinations[0] <= rd;
          alu_a <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b1101: begin // mvn
          alu_destinations[0] <= rd;
          alu_a <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b0100: begin // add
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b0101: begin // adc
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b0010: begin // sub
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b0110: begin // sbc
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b0011: begin // rsb
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b0111: begin // rsc
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b1010: begin // cmp
          alu_a <= r[rd];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 2;
        end
        4'b1011: begin // cmn
          alu_a <= r[rd];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 2;
        end
        4'b1000: begin // tst
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 2;
        end
        4'b1001: begin // teq
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 2;
        end
        4'b0000: begin // and
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b0001: begin // eor
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b1100: begin // orr
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
        4'b1110: begin // bic
          alu_destinations[0] <= rd;
          alu_a <= r[rn];
          alu_b <= !oprnd2_type ? r[oprnd2] : oprnd2;
          do_writeback <= 1;
        end
      endcase
    end
    if (do_writeback) begin
      source <= alu_result;
      destinations[0] <=  alu_destinations[0];
      destinations[1] <=  alu_destinations[1];
      case (do_writeback)
        1: begin
          r[destinations[0]] <= source[31:0];
        end
        2: begin
          cpsr <= source[31:0];
        end
        3: begin
          r[destinations[0]] <= source[63:32];
          r[destinations[1]] <= source[31:0];
        end
      endcase
    end
    r[15] <= r[15] + 1;
  end
endmodule

module arithmetic_logic_unit(
  do_execute,
  do_mul,
  opcode,
  cpsr,
  a,
  b,
  c,
  d,
  result);
  input do_execute;
  input do_mul;
  input [3:0] opcode;
  input [31:0] cpsr;
  input [31:0] a;
  input [31:0] b;
  input [31:0] c;
  input [31:0] d;
  output reg [63:0] result;
  reg [31:0] r [3:0];

  always @ (*) begin
    if (do_execute) begin
      if (do_mul) begin
        case (opcode)
          4'b0000: begin // mul
            result = a * b;
          end
          4'b0001: begin // mla
            result = a * b + c;
          end
          4'b0100: begin // umull
            result = a * b;
          end
          4'b0101: begin // umlal
            result = a * b + {c, d};
          end
          4'b0110: begin // smull
            result = $signed(a) * $signed(b);
          end
          4'b0111: begin // smlal
            result = $signed(a) * $signed(b) + {c, d};
          end
        endcase
      end
      else begin
        case (opcode)
          4'b1101: begin // mov
            result = a;
          end
          4'b1111: begin // mvn
            result = !a;
          end
          4'b0100: begin // add
            result = a + b;
          end
          4'b0101: begin // adc
            result = a + b + cpsr[29];
          end
          4'b0010: begin // sub
            result = a - b;
          end
          4'b0110: begin // sbc
            result = a - b - cpsr[29];
          end
          4'b0011: begin // rsb
            result = a - b;
          end
          4'b0111: begin // rsc
            result = a - b - cpsr[29];
          end
          4'b1010: begin // cmp
            r[0] = a + ~b + 1;
            r[1] = $signed(a) + $signed(~b) + 1;
            result[31] = r[0][31];
            result[30] = !r[0];
            result[29] = r[0][30:0] != r[0];
            result[28] = $signed(r[0][30:0]) != r[1];
            result[27:0] = cpsr[27:0];
          end
          4'b1011: begin // cmn
            r[0] = a + b + 1;
            r[1] = $signed(a) + $signed(b) + 1;
            result[31] = r[0][31];
            result[30] = !r[0];
            result[29] = r[0][30:0] != r[0];
            result[28] = $signed(r[0][30:0]) != r[1];
            result[27:0] = cpsr[27:0];
          end
          4'b1000: begin // tst
            r[0] = a & b;
            result[31] = r[0][31];
            result[30] = !r[0];
            result[29:0] = cpsr[29:0];
          end
          4'b1001: begin // teq
            r[0] = a ^ b;
            result[31] = r[0][31];
            result[30] = !r[0];
            result[29:0] = cpsr[29:0];
          end
          4'b0000: begin // and
            result = a & b;
          end
          4'b0001: begin // eor
            result = a ^ b;
          end
          4'b1100: begin // orr
            result = a | b;
          end
          4'b1110: begin // bic
            result = a & ~b;
          end
        endcase
      end
    end
  end
endmodule
