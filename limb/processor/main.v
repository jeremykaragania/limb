`define AL 4'b1110
`define NOP 28'b0011001000001111000000000000

module memory_controller (
  clk,
  addr,
  wdata,
  rdata,
  abort,
  write,
  size,
  prot,
  trans);

  input clk;
  input [31:0] addr;
  input [31:0] wdata;
  output reg [31:0] rdata;
  output reg abort;
  input write;
  input size;
  input [1:0] prot;
  input [1:0] trans;
  reg [31:0] memory [0:8191];

  initial begin
    $readmemh(`filename, memory);
  end

  always @ (posedge clk) begin
    if (trans == 2'b10 || trans == 2'b11) begin
      case (write)
        0: begin
          rdata <= memory[addr];
        end
        1: begin
          memory[addr] <= wdata;
        end
      endcase
    end
  end
endmodule

module processor (
  clk,
  n_reset);

  // Clock.
  input clk;

  // Interrupts.
  input n_reset;

  // Memory interface.
  output [31:0] addr;
  output [31:0] wdata;
  input [31:0] rdata;
  input abort;
  output reg write;
  output reg size;
  output reg [1:0] prot;
  output reg [1:0] trans;

  // Instruction pipeline.
  reg [31:0] f_instr;
  reg [31:0] d_instr;
  reg [31:0] e_instr;
  reg [3:0] d_cond;
  reg e_exec;
  reg [11:0] e_oprnd2;
  reg [11:0] e_oprnd2_t;
  reg [3:0] e_dest;
  reg [3:0] e_dest_hi;
  reg [3:0] e_dest_lo;
  reg [23:0] e_offset;
  reg e_write_dest_do;
  reg e_write_dest_m;
  reg e_write_dest_ml;
  reg e_write_cpsr;

  // Register writeback.
  reg [3:0] dest;
  reg [3:0] dest_hi;
  reg [3:0] dest_lo;
  reg write_dest_do;
  reg write_dest_m;
  reg write_dest_ml;
  reg write_cpsr;

  // Instruction cycle timing.
  reg [31:0] e_b_bl_cycle;
  reg [31:0] e_do_cycle;
  reg [31:0] e_m_ma_cycle;

  // Arithmetic logic unit and multiplier.
  output reg [31:0] a;
  output reg [31:0] b;
  output reg [31:0] c;
  output reg [31:0] d;
  output reg [3:0] opcode;
  input [31:0] result;
  reg [2:0] type;
  input [63:0] m_result;

  // Internal.
  reg [31:0] r [0:30];
  reg [31:0] cpsr;
  reg [31:0] addr_reg;
  reg write_reg;
  reg size_reg;
  reg [1:0] prot_reg;
  reg [1:0] trans_reg;

  initial begin
    write = 0;
    size = 2'b10;
    prot = 2'b10;
    trans = 2'b11;
    r[15] = 0;
    cpsr = 0;
  end

  always @ (posedge clk) begin
    f_instr <= rdata;
    d_instr <= f_instr;
    e_instr <= d_instr;
    d_cond <= f_instr[31:28];
    addr_reg <= r[15];
    write_reg <= write;
    trans_reg <= trans;

    if (d_instr[27:25] == 3'b101) begin // Branch or branch with link.
      e_b_bl_cycle <= 1;
      e_do_cycle <= 0;
      e_m_ma_cycle <= 0;
      e_offset <= d_instr[23:0];
      e_write_dest_do <= 0;
      e_write_dest_m <= 0;
      e_write_dest_ml <= 0;
      e_write_cpsr <= 0;
    end
    else if (d_instr[27:0] == `NOP) begin // No operation.
      e_b_bl_cycle <= 0;
      e_do_cycle <= 0;
      e_m_ma_cycle <= 0;
      e_write_dest_do <= 0;
      e_write_dest_m <= 0;
      e_write_dest_ml <= 0;
      e_write_cpsr <= 0;
    end
    else if (!d_instr[25] && d_instr[7] && d_instr[4]) begin // Multiply or multiply accumulate.
      e_b_bl_cycle <= 0;
      e_do_cycle <= 0;
      e_m_ma_cycle <= 1;
      e_dest <= d_instr[19:16];
      e_dest_hi <= d_instr[19:16];
      e_dest_lo <= d_instr[15:12];
      e_write_dest_do <= 0;
      e_write_dest_m <= !d_instr[23];
      e_write_dest_ml <= d_instr[23];
      e_write_cpsr <= 0;
      a <= r[d_instr[3:0]];
      b <= r[d_instr[11:8]];
      c <= r[d_instr[23]] ? r[d_instr[19:16]] : r[d_instr[15:12]];
      d <= r[d_instr[15:12]];
      type <= d_instr[23:21];
    end
    else if (d_instr[27:26] == 2'b00) begin // Data processing instruction.
      e_b_bl_cycle <= 0;
      e_do_cycle <= 1;
      e_m_ma_cycle <= 0;
      e_oprnd2_t <= d_instr[25];
      e_oprnd2 <= d_instr[11:0];
      e_dest <= d_instr[15:12];
      opcode <= d_instr[24:21];
      a <= r[d_instr[19:16]];
      b <= d_instr[25] ? d_instr[11:0] : r[d_instr[11:0]];
      if (d_instr[24:21] == 4'b1010 || d_instr[24:21] == 4'b1011 || d_instr[24:21] == 4'b1000 || d_instr[24:21] == 4'b1001) begin
        e_write_dest_do <= 1;
        e_write_dest_m <= 0;
        e_write_dest_ml <= 0;
        e_write_cpsr <= 1;
      end
      else begin
        e_write_dest_do <= 1;
        e_write_dest_m <= 0;
        e_write_dest_ml <= 0;
        e_write_cpsr <= 0;
      end
    end
    else begin
      e_write_dest_do <= 0;
      e_write_dest_m <= 0;
      e_write_dest_ml <= 0;
      e_write_cpsr <= 0;
      e_exec <= 0;
    end

    case (d_cond)
      4'b0000: begin // EQ
        if (cpsr[30]) begin
          e_exec <= 1;
        end
      end
      4'b0001: begin // NE
        if (!cpsr[30]) begin
          e_exec <= 1;
        end
      end
      4'b0010: begin // CS
        if (cpsr[29]) begin
          e_exec <= 1;
        end
      end
      4'b0011: begin // CC
        if (!cpsr[29]) begin
          e_exec <= 1;
        end
      end
      4'b0100: begin // MI
        if (cpsr[31]) begin
          e_exec <= 1;
        end
      end
      4'b0101: begin // PL
        if (!cpsr[31]) begin
          e_exec <= 1;
        end
      end
      4'b0110: begin // VS
        if (cpsr[28]) begin
          e_exec <= 1;
        end
      end
      4'b0111: begin // VC
        if (!cpsr[28]) begin
          e_exec <= 1;
        end
      end
      4'b1000: begin // HI
        if (cpsr[29] || !cpsr[30]) begin
          e_exec <= 1;
        end
      end
      4'b1001: begin // LS
        if (!cpsr[29] || cpsr[30]) begin
          e_exec <= 1;
        end
      end
      4'b1010: begin // GE
        if (cpsr[31] == cpsr[28]) begin
          e_exec <= 1;
        end
      end
      4'b1011: begin // LT
        if (cpsr[31] != cpsr[28]) begin
          e_exec <= 1;
        end
      end
      4'b1100: begin // GT
        if (!cpsr[28] || cpsr[31] == cpsr[28]) begin
          e_exec <= 1;
        end
      end
      4'b1101: begin // LE
        if (cpsr[28] || cpsr[31] != cpsr[28]) begin
          e_exec <= 1;
        end
      end
      4'b1110: begin // AL
        e_exec <= 1;
      end
    endcase

    if (e_exec) begin
      write_dest_do <= e_write_dest_do;
      write_dest_m <= e_write_dest_m;
      write_dest_ml <= e_write_dest_ml;
      write_cpsr <= e_write_cpsr;
      if (e_b_bl_cycle) begin // Branch or branch with link.
        f_instr <= {`AL, `NOP};
        d_instr <= {`AL, `NOP};
        e_instr <= {`AL, `NOP};
        case (e_b_bl_cycle)
          1: begin
            trans <= 2'b10;
            r[15] <= e_offset;
            e_b_bl_cycle <= e_b_bl_cycle + 1;
          end
          2: begin
            trans <= 2'b11;
            r[15] <= r[15] + 1;
            e_b_bl_cycle <= e_b_bl_cycle + 1;
          end
          3: begin
            trans <= 2'b11;
            r[15] <= r[15] + 1;
            e_b_bl_cycle <= 0;
          end
        endcase
      end
      else if (e_do_cycle) begin // Data operation.
        trans <= 2'b11;
        r[15] <= r[15] + 1;
        dest <= e_dest;
      end
      else if (e_m_ma_cycle) begin // Multiply or multiply accumulate.
        trans <= 2'b11;
        r[15] <= r[15] + 1;
        dest <= e_dest;
        dest_lo <= e_dest_lo;
        dest_hi <= e_dest_hi;
      end
      else begin // No operation.
        trans <= 2'b11;
        r[15] <= r[15] + 1;
      end
    end
    else begin
      trans <= 2'b11;
      r[15] <= r[15] + 1;
      write <= 0;
    end

    if (write_dest_do) begin
      r[dest] <= result;
    end
    else if (write_dest_m) begin
      r[dest] <= m_result;
    end
    else if (write_dest_ml) begin
      r[dest_hi] <= m_result[63:32];
      r[dest_lo] <= m_result[31:0];
    end
    else if (write_cpsr) begin
      cpsr <= result;
    end
  end
endmodule

module arithmetic_logic_unit(
  clk,
  a,
  b,
  cpsr,
  opcode,
  result);

  input clk;
  input [31:0] a;
  input [31:0] b;
  input [31:0] cpsr;
  input [0:3] opcode;
  output reg [31:0] result;

  always @ (posedge clk) begin
    case (opcode)
      4'b1101: begin // MOV
        result <= b;
      end
      4'b1111: begin // MVN
        result <= ~b;
      end
      4'b0100: begin // ADD
        result <= a + b;
      end
      4'b0101: begin // ADC
        result <= a + b + cpsr[29];
      end
      4'b0010: begin // SUB
        result <= a - b;
      end
      4'b0110: begin // SBC
        result <= a - b - cpsr[29];
      end
      4'b0011: begin // RSB
        result <= b - a;
      end
      4'b0111: begin // RSC
        result <= b - a - cpsr[29];
      end
      4'b1010: begin // CMP
        result[31] <= ($unsigned(a) + $unsigned(~b) + $unsigned(1)) >> 31;
        result[30] <= !(a + ~b + 1);
        result[29] <= $unsigned((a + ~b + 1) >> 1) != (a + ~b + 1);
        result[28] <= $signed((a + ~b + 1) >> 1) != ($signed(a) + $signed(~b) + $unsigned(1));
        result[27:0] <= cpsr[27:0];
      end
      4'b1011: begin // CMN
        result[31] <= ($unsigned(a) + $unsigned(b) + $unsigned(1)) >> 31;
        result[30] <= !(a + ~b + 1);
        result[29] <= $unsigned((a + b + 1) >> 1) != (a + b + 1);
        result[28] <= $signed((a + b + 1) >> 1) != ($signed(a) + $signed(b) + $unsigned(1));
        result[27:0] <= cpsr[27:0];
      end
      4'b1000: begin // TST
        result[31] <= (a & b) >> 31;
        result[30] <= !(a & b);
        result[29:0] <= cpsr[29:0];
      end
      4'b1001: begin // TEQ
        result[31] <= (a ^ b) >> 31;
        result[30] <= !(a & b);
        result[29:0] <= cpsr[29:0];
      end
      4'b0000: begin // AND
        result <= a & b;
      end
      4'b0001: begin // EOR
        result <= a ^ b;
      end
      4'b1100: begin // ORR
        result <= a | b;
      end
      4'b1110: begin // BIC
        result <= a & ~b;
      end
    endcase
  end
endmodule

module multiplier(
  clk,
  a,
  b,
  c,
  d,
  type,
  result);

  input clk;
  input [31:0] a;
  input [31:0] b;
  input [31:0] c;
  input [31:0] d;
  input [2:0] type;
  output reg [63:0] result;

  always @ (posedge clk) begin
    case (type)
      3'b000: begin // MUL
        result <= $signed(a) * $signed(b);
      end
      3'b001: begin // MLA
        result <= $signed(a) * $signed(b) + $signed(c);
      end
      3'b100: begin // SMULL
        result <= $unsigned(a) * $unsigned(b);
      end
      3'b101: begin // SMLAL
        result <= $unsigned(a) * $unsigned(b) + $signed({c, d});
      end
      3'b110: begin // UMULL
        result <= $unsigned(a) * $unsigned(b);
      end
      3'b111: begin // UMLAL
        result <= $unsigned(a) * $unsigned(b) + $unsigned({c, d});
      end
    endcase
  end
endmodule
