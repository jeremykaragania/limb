`define AL 4'b1110
`define NOP 28'b0011001000001111000000000000

module memory_controller (
  input clk,
  input [31:0] addr,
  input [31:0] wdata,
  output reg [31:0] rdata,
  output reg abort,
  input write,
  input size,
  input [1:0] prot,
  input[1:0] trans);

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

module register_file (
  input clk,
  // Register write.
  input [5:0] rw_i_i,
  input [31:0] rw_i,
  input [31:0] cpsr_i,

  // Register read.
  input [5:0] rr1_i_i,
  input [5:0] rr2_i_i,
  input [5:0] rr3_i_i,
  input [5:0] rr4_i_i,
  output reg [31:0] rr1_o,
  output reg [31:0] rr2_o,
  output reg [31:0] rr3_o,
  output reg [31:0] rr4_o,
  output reg [31:0] cpsr_o);

  reg [31:0] r [0:30];
  reg [31:0] cpsr;

  initial begin
    cpsr = 32'b0;
    for (integer i = 0; i < 31; ++i) begin
      r[i] = 1'b0;
    end
  end

  always @ (*) begin
    r[rw_i_i] = rw_i;
    rr1_o = r[rr1_i_i];
    rr2_o = r[rr2_i_i];
    rr3_o = r[rr3_i_i];
    rr4_o = r[rr4_i_i];
    cpsr = cpsr_i;
    cpsr_o = cpsr;
  end
endmodule

module instruction_fetch (
  input clk,
  input write_pc_i,
  input [31:0] pc_i,
  input [31:0] instr_i,
  output reg [31:0] pc_o,
  output reg [31:0] instr_o);

  reg [31:0] pc_r;

  initial begin
    pc_r = 32'b0;
    pc_o = 32'b0;
    instr_o = 32'b0;
  end

  always @ (posedge clk) begin
    if (write_pc_i) begin
      pc_r <= pc_i;
    end
    else begin
      pc_r <= pc_r + 32'b1;
    end

    pc_o <= pc_r;
    instr_o <= instr_i;
  end
endmodule

module processor (
  input clk,
  input n_reset);

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
  reg [23:0] e_offset;
  reg e_write_dest_do;
  reg e_write_dest_m;
  reg e_write_cpsr;

  // Register writeback.
  reg [3:0] dest;
  reg write_dest_do;
  reg write_dest_m;
  reg write_cpsr;

  // Instruction cycle timing.
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

  // Components.
  instruction_fetch if_m (
    .clk(clk),
    .instr_i(rdata));

  arithmetic_logic_unit alu (
    .clk(clk),
    .a(a),
    .b(b),
    .cpsr(cpsr),
    .opcode(opcode),
    .result(result));

  multiplier m(
    .clk(clk),
    .a(a),
    .b(b),
    .c(c),
    .d(d),
    .type(type),
    .result(m_result));

  initial begin
    write = 1'b0;
    size = 2'b10;
    prot = 2'b10;
    trans = 2'b11;
    r[15] = 32'b0;
    cpsr = 32'b0;
  end

  always @ (posedge clk) begin
    f_instr <= if_m.instr_o;
    d_instr <= f_instr;
    e_instr <= d_instr;
    d_cond <= f_instr[31:28];
    addr_reg <= r[15];
    write_reg <= write;
    trans_reg <= trans;

    if (d_instr[27:0] == `NOP) begin // No operation.
      e_do_cycle <= 1'b0;
      e_m_ma_cycle <= 1'b0;
      e_write_dest_do <= 1'b0;
      e_write_dest_m <= 1'b0;
      e_write_cpsr <= 1'b0;
    end
    else if (!d_instr[25] && d_instr[7] && d_instr[4]) begin // Multiply or multiply accumulate.
      e_do_cycle <= 1'b0;
      e_m_ma_cycle <= 1'b1;
      e_dest <= d_instr[19:16];
      e_write_dest_do <= 1'b0;
      e_write_dest_m <= !d_instr[23];
      e_write_cpsr <= 1'b0;
      a <= r[d_instr[3:0]];
      b <= r[d_instr[11:8]];
      c <= r[d_instr[23]] ? r[d_instr[19:16]] : r[d_instr[15:12]];
      d <= r[d_instr[15:12]];
      type <= d_instr[23:21];
    end
    else if (d_instr[27:26] == 2'b00) begin // Data processing instruction.
      e_do_cycle <= 1'b1;
      e_m_ma_cycle <= 1'b0;
      e_oprnd2_t <= d_instr[25];
      e_oprnd2 <= d_instr[11:0];
      e_dest <= d_instr[15:12];
      opcode <= d_instr[24:21];
      a <= r[d_instr[19:16]];
      b <= d_instr[25] ? d_instr[11:0] : r[d_instr[11:0]];
      if (d_instr[24:21] == 4'b1010 || d_instr[24:21] == 4'b1011 || d_instr[24:21] == 4'b1000 || d_instr[24:21] == 4'b1001) begin
        e_write_dest_do <= 1'b1;
        e_write_dest_m <= 1'b0;
        e_write_cpsr <= 1'b1;
      end
      else begin
        e_write_dest_do <= 1'b1;
        e_write_dest_m <= 1'b0;
        e_write_cpsr <= 1'b0;
      end
    end
    else begin
      e_write_dest_do <= 1'b0;
      e_write_dest_m <= 1'b0;
      e_write_cpsr <= 1'b0;
      e_exec <= 1'b0;
    end

    case (d_cond)
      4'b0000: begin // EQ
        if (cpsr[30]) begin
          e_exec <= 1'b1;
        end
      end
      4'b0001: begin // NE
        if (!cpsr[30]) begin
          e_exec <= 1'b1;
        end
      end
      4'b0010: begin // CS
        if (cpsr[29]) begin
          e_exec <= 1'b1;
        end
      end
      4'b0011: begin // CC
        if (!cpsr[29]) begin
          e_exec <= 1'b1;
        end
      end
      4'b0100: begin // MI
        if (cpsr[31]) begin
          e_exec <= 1'b1;
        end
      end
      4'b0101: begin // PL
        if (!cpsr[31]) begin
          e_exec <= 1'b1;
        end
      end
      4'b0110: begin // VS
        if (cpsr[28]) begin
          e_exec <= 1'b1;
        end
      end
      4'b0111: begin // VC
        if (!cpsr[28]) begin
          e_exec <= 1'b1;
        end
      end
      4'b1000: begin // HI
        if (cpsr[29] || !cpsr[30]) begin
          e_exec <= 1'b1;
        end
      end
      4'b1001: begin // LS
        if (!cpsr[29] || cpsr[30]) begin
          e_exec <= 1'b1;
        end
      end
      4'b1010: begin // GE
        if (cpsr[31] == cpsr[28]) begin
          e_exec <= 1'b1;
        end
      end
      4'b1011: begin // LT
        if (cpsr[31] != cpsr[28]) begin
          e_exec <= 1'b1;
        end
      end
      4'b1100: begin // GT
        if (!cpsr[28] || cpsr[31] == cpsr[28]) begin
          e_exec <= 1'b1;
        end
      end
      4'b1101: begin // LE
        if (cpsr[28] || cpsr[31] != cpsr[28]) begin
          e_exec <= 1'b1;
        end
      end
      4'b1110: begin // AL
        e_exec <= 1'b1;
      end
    endcase

    if (e_exec) begin
      write_dest_do <= e_write_dest_do;
      write_dest_m <= e_write_dest_m;
      write_cpsr <= e_write_cpsr;
      if (e_do_cycle) begin // Data operation.
        trans <= 2'b11;
        r[15] <= r[15] + 32'b1;
        dest <= e_dest;
      end
      else if (e_m_ma_cycle) begin // Multiply or multiply accumulate.
        trans <= 2'b11;
        r[15] <= r[15] + 32'b1;
        dest <= e_dest;
      end
      else begin // No operation.
        trans <= 2'b11;
        r[15] <= r[15] + 32'b1;
      end
    end
    else begin
      trans <= 2'b11;
      r[15] <= r[15] + 32'b1;
      write <= 1'b0;
    end

    if (write_dest_do) begin
      r[dest] <= result;
    end
    else if (write_dest_m) begin
      r[dest] <= m_result;
    end
    else if (write_cpsr) begin
      cpsr <= result;
    end
  end
endmodule

module arithmetic_logic_unit (
  input clk,
  input [31:0] a,
  input [31:0] b,
  input [31:0] cpsr,
  input [0:3] opcode,
  output reg [31:0] result);

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
        result[31] <= ($unsigned(a) + $unsigned(~b) + $unsigned(1)) >> 32'd31;
        result[30] <= !(a + ~b + 1);
        result[29] <= $unsigned((a + ~b + 32'b1) >> 32'b1) != (a + ~b + 32'b1);
        result[28] <= $signed((a + ~b + 32'b1) >> 32'b1) != ($signed(a) + $signed(~b) + $unsigned(32'b1));
        result[27:0] <= cpsr[27:0];
      end
      4'b1011: begin // CMN
        result[31] <= ($unsigned(a) + $unsigned(b) + $unsigned(1)) >> 32'd31;
        result[30] <= !(a + ~b + 32'b1);
        result[29] <= $unsigned((a + b + 32'b1) >> 32'b1) != (a + b + 32'b1);
        result[28] <= $signed((a + b + 32'b1) >> 32'b1) != ($signed(a) + $signed(b) + $unsigned(32'b1));
        result[27:0] <= cpsr[27:0];
      end
      4'b1000: begin // TST
        result[31] <= (a & b) >> 32'd31;
        result[30] <= !(a & b);
        result[29:0] <= cpsr[29:0];
      end
      4'b1001: begin // TEQ
        result[31] <= (a ^ b) >> 32'd31;
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
  input clk,
  input [31:0] a,
  input [31:0] b,
  input [31:0] c,
  input [31:0] d,
  input [2:0] type,
  output reg [63:0] result);

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
