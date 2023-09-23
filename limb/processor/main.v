module random_access_memory(
  clk,
  a,
  din,
  dout,
  rw);
  parameter filename = "boot_rom";
  input clk;
  input [31:0] a;
  input [31:0] din;
  output reg [31:0] dout;
  input rw;
  reg [31:0] mem [0:8191];

  initial begin
    $readmemh(filename, mem);
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
  reg [31:0] if_ram_a;
  reg [31:0] if_ram_din;
  wire [31:0] if_ram_dout;
  reg if_ram_rw;
  wire [31:0] if_instruction = if_ram_dout;
  wire [3:0] if_cond = if_instruction[31:28];
  wire if_oprnd2_type = if_instruction[25];
  wire [3:0] if_rn = if_instruction[19:16];
  wire [3:0] if_rd = if_instruction[15:12];
  wire [3:0] if_rs = if_instruction[11:8];
  wire [3:0] if_rm = if_instruction[3:0];
  wire [11:0] if_oprnd2 = if_instruction[11:0];
  wire [3:0] if_opcode = if_instruction[24:21];
  reg [3:0] id_cond;
  reg id_oprnd2_type;
  reg [3:0] id_rn;
  reg [3:0] id_rd;
  reg [3:0] id_rs;
  reg [3:0] id_rm;
  reg [11:0] id_oprnd2;
  reg [3:0] id_opcode;
  reg id_do_execute;
  reg id_do_mul;
  reg id_do_branch;
  reg [1:0] id_do_writeback;
  reg [23:0] id_offset;
  reg [31:0] id_alu_a;
  reg [31:0] id_alu_b;
  reg [31:0] id_alu_c;
  reg [31:0] id_alu_d;
  reg [3:0]  id_alu_destinations [1:0];
  reg [1:0] ie_do_writeback;
  reg [3:0]  ie_alu_destinations [1:0];
  wire [63:0] ie_alu_result;
  reg [1:0] wb_do_writeback;
  reg [63:0] wb_source;
  reg [3:0] wb_destinations [1:0];
  reg [31:0] r [0:30];
  reg [31:0] cpsr;
  random_access_memory ram(
    .clk(clk),
    .a(if_ram_a),
    .din(if_ram_din),
    .dout(if_ram_dout),
    .rw(if_ram_rw));
  arithmetic_logic_unit alu(
    .clk(clk),
    .do_execute(id_do_execute),
    .do_mul(id_do_mul),
    .opcode(id_opcode),
    .a(id_alu_a),
    .b(id_alu_b),
    .c(id_alu_c),
    .d(id_alu_d),
    .result(ie_alu_result));

  task forward_operands;
    begin
      if (if_rn == id_alu_destinations[0]) begin
        id_alu_a <= wb_source[31:0];
      end
      else begin
        id_alu_a <= r[if_rn];
      end
      if (!if_oprnd2_type && if_oprnd2 == id_alu_destinations[0]) begin
        id_alu_b <= wb_source[31:0];
      end
      else begin
        id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
      end
    end
  endtask

  initial begin
    r[15] = 0;
    cpsr = 0;
  end

  always @ (posedge clk) begin
    if_ram_a <= r[15];
    if_ram_rw <= 0;
    id_cond <= if_instruction[31:28];
    id_oprnd2_type <= if_instruction[25];
    id_rn <= if_instruction[19:16];
    id_rd <= if_instruction[15:12];
    id_rs <= if_instruction[11:8];
    id_rm <= if_instruction[3:0];
    id_oprnd2 <= if_instruction[11:0];
    id_opcode <= if_instruction[24:21];
    ie_do_writeback <= id_do_writeback;
    ie_alu_destinations[0] <= id_alu_destinations[0];
    ie_alu_destinations[1] <= id_alu_destinations[1];
    wb_do_writeback <= ie_do_writeback;
    wb_source <= ie_alu_result;
    wb_destinations[0] <=  ie_alu_destinations[0];
    wb_destinations[1] <=  ie_alu_destinations[1];

    case (if_cond)
      4'b0000: begin // eq
        if (cpsr[30]) begin
          id_do_execute <= 1;
        end
      end
      4'b0001: begin // ne
        if (!cpsr[30]) begin
          id_do_execute <= 1;
        end
      end
      4'b0010: begin // cs
        if (cpsr[29]) begin
          id_do_execute <= 1;
        end
      end
      4'b0011: begin // cc
        if (!cpsr[29]) begin
          id_do_execute <= 1;
        end
      end
      4'b0100: begin // mi
        if (cpsr[31]) begin
          id_do_execute <= 1;
        end
      end
      4'b0101: begin // pl
        if (!cpsr[31]) begin
          id_do_execute <= 1;
        end
      end
      4'b0110: begin // vs
        if (cpsr[28]) begin
          id_do_execute <= 1;
        end
      end
      4'b0111: begin // vc
        if (!cpsr[28]) begin
          id_do_execute <= 1;
        end
      end
      4'b1000: begin // hi
        if (cpsr[29] || !cpsr[30]) begin
          id_do_execute <= 1;
        end
      end
      4'b1001: begin // ls
        if (!cpsr[29] || cpsr[30]) begin
          id_do_execute <= 1;
        end
      end
      4'b1010: begin // ge
        if (cpsr[31] == cpsr[28]) begin
          id_do_execute <= 1;
        end
      end
      4'b1011: begin // lt
        if (cpsr[31] != cpsr[28]) begin
          id_do_execute <= 1;
        end
      end
      4'b1100: begin // gt
        if (!cpsr[28] || cpsr[31] == cpsr[28]) begin
          id_do_execute <= 1;
        end
      end
      4'b1101: begin // le
        if (cpsr[28] || cpsr[31] != cpsr[28]) begin
          id_do_execute <= 1;
        end
      end
      4'b1110: begin // al
        id_do_execute <= 1;
      end
    endcase
    if (!if_instruction[25] && if_instruction[4]) begin
      id_do_mul <= 1;
      case (if_opcode)
        4'b0000: begin // mul
          id_alu_destinations[0] <= if_rn;
          id_alu_a <= r[if_rd];
          id_alu_b <= r[if_rs];
          id_do_writeback <= 1;
        end
        4'b0001: begin // mla
          id_alu_destinations[0] <= if_rn;
          id_alu_a <= r[if_rd];
          id_alu_b <= r[if_rs];
          id_alu_c <= r[if_rm];
          id_do_writeback <= 1;
        end
        4'b0100: begin // umull
          id_alu_destinations[0] <= if_rd;
          id_alu_destinations[1] <= if_rn;
          id_alu_a <= r[if_rm];
          id_alu_b <= r[if_rs];
          id_do_writeback <= 3;
        end
        4'b0101: begin // umlal
          id_alu_destinations[0] <= if_rd;
          id_alu_destinations[1] <= if_rn;
          id_alu_a <= r[if_rm];
          id_alu_b <= r[if_rs];
          id_alu_c <= r[if_rd];
          id_alu_d <= r[if_rn];
          id_do_writeback <= 3;
        end
        4'b0110: begin // smull
          id_alu_destinations[0] <= if_rd;
          id_alu_destinations[1] <= if_rn;
          id_alu_a <= r[if_rm];
          id_alu_b <= r[if_rs];
          id_do_writeback <= 3;
        end
        4'b0111: begin // smlal
          id_alu_destinations[0] <= if_rd;
          id_alu_destinations[1] <= if_rn;
          id_alu_a <= r[if_rm];
          id_alu_b <= r[if_rs];
          id_alu_c <= r[if_rd];
          id_alu_d <= r[if_rn];
          id_do_writeback <= 3;
        end
      endcase
    end
    else if (if_instruction[27:24] == 4'b1010) begin // b
      id_do_writeback <= 0;
      id_do_execute <= 0;
      id_do_branch <= 1;
      id_offset <= if_instruction[23:0];
    end
    else if (if_instruction[27:24] == 4'b0011 && if_instruction[15:12] == 4'b1111) begin // nop
      id_do_writeback <= 0;
      id_do_execute <= 0;
    end
    else begin
      case (if_opcode)
        4'b1101: begin // mov
          id_alu_destinations[0] <= if_rd;
          id_do_writeback <= 1;
          if (!if_oprnd2_type) begin
            if ((id_do_writeback) && ((if_oprnd2 == id_alu_destinations[0]))) begin
              id_alu_a <= id_alu_a;
            end
            else if ((ie_do_writeback) && ((if_oprnd2 == ie_alu_destinations[0]))) begin
              id_alu_a <= ie_alu_result;
            end
            else if ((wb_do_writeback) && ((if_oprnd2 == wb_destinations[0]))) begin
              id_alu_a <= wb_source;
            end
            else begin
              id_alu_a <= r[if_oprnd2];
            end
          end
          else begin
            id_alu_a <= if_oprnd2;
          end
        end
        4'b1101: begin // mvn
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_do_writeback <= 1;
        end
        4'b0100: begin // add
          id_alu_destinations[0] <= if_rd;
          id_do_writeback <= 1;
          forward_operands();
        end
        4'b0101: begin // adc
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_alu_c <= cpsr[31:0];
          id_do_writeback <= 1;
        end
        4'b0010: begin // sub
          id_alu_destinations[0] <= if_rd;
          id_do_writeback <= 1;
          forward_operands();
        end
        4'b0110: begin // sbc
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_alu_c <= cpsr[31:0];
          id_do_writeback <= 1;
        end
        4'b0011: begin // rsb
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_do_writeback <= 1;
        end
        4'b0111: begin // rsc
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_alu_c <= cpsr[31:0];
          id_do_writeback <= 1;
        end
        4'b1010: begin // cmp
          id_alu_a <= r[if_rd];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_alu_c <= cpsr[31:0];
          id_do_writeback <= 2;
        end
        4'b1011: begin // cmn
          id_alu_a <= r[if_rd];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_alu_c <= cpsr[31:0];
          id_do_writeback <= 2;
        end
        4'b1000: begin // tst
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_alu_c <= cpsr[31:0];
          id_do_writeback <= 2;
        end
        4'b1001: begin // teq
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_alu_c <= cpsr[31:0];
          id_do_writeback <= 2;
        end
        4'b0000: begin // and
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_do_writeback <= 1;
        end
        4'b0001: begin // eor
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_do_writeback <= 1;
        end
        4'b1100: begin // orr
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_do_writeback <= 1;
        end
        4'b1110: begin // bic
          id_alu_destinations[0] <= if_rd;
          id_alu_a <= r[if_rn];
          id_alu_b <= !if_oprnd2_type ? r[if_oprnd2] : if_oprnd2;
          id_do_writeback <= 1;
        end
      endcase
    end
    case (wb_do_writeback)
      1: begin
        r[wb_destinations[0]] <= wb_source[31:0];
      end
      2: begin
        cpsr <= wb_source[31:0];
      end
      3: begin
        r[wb_destinations[0]] <= wb_source[63:32];
        r[wb_destinations[1]] <= wb_source[31:0];
      end
    endcase
    if (id_do_branch) begin
      r[15] <= id_offset;
    end
    else begin
      r[15] <= r[15] + 1;
    end
  end
endmodule

module arithmetic_logic_unit(
  clk,
  do_execute,
  do_mul,
  opcode,
  a,
  b,
  c,
  d,
  result);
  input clk;
  input do_execute;
  input do_mul;
  input [3:0] opcode;
  input [31:0] a;
  input [31:0] b;
  input [31:0] c;
  input [31:0] d;
  output reg [63:0] result;
  reg [31:0] r [3:0];

  always @ (posedge clk) begin
    if (do_execute) begin
      if (do_mul) begin
        case (opcode)
          4'b0000: begin // mul
            result <= a * b;
          end
          4'b0001: begin // mla
            result <= a * b + c;
          end
          4'b0100: begin // umull
            result <= a * b;
          end
          4'b0101: begin // umlal
            result <= a * b + {c, d};
          end
          4'b0110: begin // smull
            result <= $signed(a) * $signed(b);
          end
          4'b0111: begin // smlal
            result <= $signed(a) * $signed(b) + {c, d};
          end
        endcase
      end
      else begin
        case (opcode)
          4'b1101: begin // mov
            result <= a;
          end
          4'b1111: begin // mvn
            result <= !a;
          end
          4'b0100: begin // add
            result <= a + b;
          end
          4'b0101: begin // adc
            result <= a + b + c[29];
          end
          4'b0010: begin // sub
            result <= a - b;
          end
          4'b0110: begin // sbc
            result <= a - b - c[29];
          end
          4'b0011: begin // if_rsb
            result <= a - b;
          end
          4'b0111: begin // if_rsc
            result <= a - b - c[29];
          end
          4'b1010: begin // cmp
            r[0] = a + ~b + 1;
            r[1] = $signed(a) + $signed(~b) + 1;
            result[31] = r[0][31];
            result[30] = !r[0];
            result[29] = r[0][30:0] != r[0];
            result[28] = $signed(r[0][30:0]) != r[1];
            result[27:0] = c[27:0];
          end
          4'b1011: begin // cmn
            r[0] = a + b + 1;
            r[1] = $signed(a) + $signed(b) + 1;
            result[31] = r[0][31];
            result[30] = !r[0];
            result[29] = r[0][30:0] != r[0];
            result[28] = $signed(r[0][30:0]) != r[1];
            result[27:0] = c[27:0];
          end
          4'b1000: begin // tst
            r[0] = a & b;
            result[31] = r[0][31];
            result[30] = !r[0];
            result[29:0] = c[29:0];
          end
          4'b1001: begin // teq
            r[0] = a ^ b;
            result[31] = r[0][31];
            result[30] = !r[0];
            result[29:0] = c[29:0];
          end
          4'b0000: begin // and
            result <= a & b;
          end
          4'b0001: begin // eor
            result <= a ^ b;
          end
          4'b1100: begin // orr
            result <= a | b;
          end
          4'b1110: begin // bic
            result <= a & ~b;
          end
        endcase
      end
    end
  end
endmodule

module central_processing_unit(
  clk);
  input clk;
  control_unit cu(
    .clk(clk));
endmodule
