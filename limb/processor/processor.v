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
    rdata = 32'b0;
    abort = 32'b0;
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
      r[i] = 32'b0;
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

module instruction_decode (
  input clk,

  input [31:0] instr_i,

  input [31:0] rr1_i,
  input [31:0] rr2_i,
  input [31:0] rr3_i,
  input [31:0] rr4_i,

  output reg [5:0] rr1_i_o,
  output reg [5:0] rr2_i_o,
  output reg [5:0] rr3_i_o,
  output reg [5:0] rr4_i_o,

  output reg [3:0] cond_o,
  output reg e_exec,
  output reg [11:0] e_oprnd2,
  output reg [3:0] e_dest,

  output reg e_write_dest_do,
  output reg e_write_dest_m,
  output reg e_write_cpsr,

  output reg [31:0] e_do_cycle,
  output reg [31:0] e_m_ma_cycle,

  output reg [31:0] a,
  output reg [31:0] b,
  output reg [31:0] c,
  output reg [31:0] d,
  output reg [3:0] opcode,
  output reg [2:0] type);

  reg [31:0] cpsr;

  initial begin
    cpsr = 32'b0;
  end

  always @ (*) begin
    cond_o = instr_i[31:28];
    if (instr_i[27:0] == `NOP) begin // No operation.
      e_do_cycle = 1'b0;
      e_write_dest_do = 1'b0;
      e_write_dest_m = 1'b0;
      e_write_cpsr = 1'b0;
    end
    else if (!instr_i[25] && instr_i[7] && instr_i[4]) begin // Multiply or multiply accumulate.
      e_do_cycle = 1'b0;
      e_m_ma_cycle = 1'b1;
      e_dest = instr_i[19:16];
      e_write_dest_do = 1'b0;
      e_write_dest_m = !instr_i[23];
      e_write_cpsr = 1'b0;
      rr1_i_o = instr_i[3:0];
      rr2_i_o = instr_i[11:8];
      rr3_i_o = instr_i[19:16];
      rr4_i_o = instr_i[15:12];
      a = rr1_i;
      b = rr2_i;
      c = rr3_i;
      d = rr4_i;
      type = instr_i[23:21];
    end
    else if (instr_i[27:26] == 2'b00) begin // Data processing instruction.
      e_do_cycle = 1'b1;
      e_oprnd2 = instr_i[11:0];
      e_dest = instr_i[15:12];
      opcode = instr_i[24:21];
      rr1_i_o = instr_i[19:16];
      rr2_i_o = e_oprnd2;
      a = rr1_i;
      b = instr_i[25] ? instr_i[11:0] : rr2_i;
      if (instr_i[24:21] == 4'b1010 || instr_i[24:21] == 4'b1011 || instr_i[24:21] == 4'b1000 || instr_i[24:21] == 4'b1001) begin
        e_write_dest_do = 1'b1;
        e_write_dest_m = 1'b0;
        e_write_cpsr = 1'b1;
      end
      else begin
        e_write_dest_do = 1'b1;
        e_write_dest_m = 1'b0;
        e_write_cpsr = 1'b0;
      end
    end
    else begin
      e_write_dest_do = 1'b0;
      e_write_dest_m = 1'b0;
      e_write_cpsr = 1'b0;
      e_exec = 1'b0;
    end

    case (cond_o)
      4'b0000: begin // EQ
        if (cpsr[30]) begin
          e_exec = 1'b1;
        end
      end
      4'b0001: begin // NE
        if (!cpsr[30]) begin
          e_exec = 1'b1;
        end
      end
      4'b0010: begin // CS
        if (cpsr[29]) begin
          e_exec = 1'b1;
        end
      end
      4'b0011: begin // CC
        if (!cpsr[29]) begin
          e_exec = 1'b1;
        end
      end
      4'b0100: begin // MI
        if (cpsr[31]) begin
          e_exec = 1'b1;
        end
      end
      4'b0101: begin // PL
        if (!cpsr[31]) begin
          e_exec = 1'b1;
        end
      end
      4'b0110: begin // VS
        if (cpsr[28]) begin
          e_exec = 1'b1;
        end
      end
      4'b0111: begin // VC
        if (!cpsr[28]) begin
          e_exec = 1'b1;
        end
      end
      4'b1000: begin // HI
        if (cpsr[29] || !cpsr[30]) begin
          e_exec = 1'b1;
        end
      end
      4'b1001: begin // LS
        if (!cpsr[29] || cpsr[30]) begin
          e_exec = 1'b1;
        end
      end
      4'b1010: begin // GE
        if (cpsr[31] == cpsr[28]) begin
          e_exec = 1'b1;
        end
      end
      4'b1011: begin // LT
        if (cpsr[31] != cpsr[28]) begin
          e_exec = 1'b1;
        end
      end
      4'b1100: begin // GT
        if (!cpsr[28] || cpsr[31] == cpsr[28]) begin
          e_exec = 1'b1;
        end
      end
      4'b1101: begin // LE
        if (cpsr[28] || cpsr[31] != cpsr[28]) begin
          e_exec = 1'b1;
        end
      end
      4'b1110: begin // AL
        e_exec = 1'b1;
      end
    endcase
  end
endmodule

module processor (
  input clk,
  input n_reset,
  output [31:0] addr);

  // Register file.
  reg [5:0] rw_i_i;
  reg [31:0] rw_i;
  reg [31:0] cpsr_i;
  wire [5:0] rr1_i_i_w;
  wire [5:0] rr2_i_i_w;
  wire [5:0] rr3_i_i_w;
  wire [5:0] rr4_i_i_w;
  wire [31:0] rr1_o_w;
  wire [31:0] rr2_o_w;
  wire [31:0] rr3_o_w;
  wire [31:0] rr4_o_w;
  wire [31:0] cpsr_o_w;

  // Instruction fetch.
  wire write_pc_w;
  wire [31:0] instr_f_w;
  wire [31:0] pc_w;

  // Instruction decode.
  wire [3:0] cond_o_w;
  wire e_exec_w;
  wire [11:0] e_oprnd2_w;
  wire [3:0] e_dest_w;
  wire e_write_dest_do_w;
  wire e_write_dest_m_w;
  wire e_write_cpsr_w;

  // Memory interface.
  output [31:0] wdata;
  input [31:0] rdata;
  input abort;
  output reg write;
  output reg size;
  output reg [1:0] prot;
  output reg [1:0] trans;

  // Register writeback.
  reg [3:0] dest;
  reg write_dest_do;
  reg write_dest_m;
  reg write_cpsr;

  // Instruction cycle timing.
  wire [31:0] e_do_cycle_w;
  wire [31:0] e_m_ma_cycle_w;

  // Arithmetic logic unit and multiplier.
  wire [31:0] a_w;
  wire [31:0] b_w;
  wire [31:0] c_w;
  wire [31:0] d_w;
  wire [3:0] opcode_w;
  wire [31:0] result_w;
  wire [2:0] type_w;
  wire [63:0] m_result_w;

  // Internal.
  reg [31:0] addr_reg;
  reg write_reg;
  reg size_reg;
  reg [1:0] prot_reg;
  reg [1:0] trans_reg;

  register_file rf_m (
    .clk(clk),
    .rw_i_i(rw_i_i),
    .rw_i(rw_i),
    .cpsr_i(cpsr_i),

    .rr1_i_i(rr1_i_i_w),
    .rr2_i_i(rr2_i_i_w),
    .rr3_i_i(rr3_i_i_w),
    .rr4_i_i(rr4_i_i_w),
    .rr1_o(rr1_o_w),
    .rr2_o(rr2_o_w),
    .rr3_o(rr3_o_w),
    .rr4_o(rr4_o_w),
    .cpsr_o(cpsr_o_w)
    );

  instruction_fetch if_m (
    .clk(clk),
    .write_pc_i(write_pc_w),
    .pc_i(pc_w),
    .instr_i(rdata),

    .pc_o(addr),
    .instr_o(instr_f_w));

  instruction_decode id_m (
    .clk(clk),
    .instr_i(instr_f_w),

    .rr1_i(rr1_o_w),
    .rr2_i(rr2_o_w),
    .rr3_i(rr3_o_w),
    .rr4_i(rr4_o_w),

    .rr1_i_o(rr1_i_i_w),
    .rr2_i_o(rr2_i_i_w),
    .rr3_i_o(rr3_i_i_w),
    .rr4_i_o(rr4_i_i_w),

    .cond_o(cond_o_w),
    .e_exec(e_exec_w),
    .e_oprnd2(e_oprnd2_w),
    .e_dest(e_dest_w),

    .e_write_dest_do(e_write_dest_do_w),
    .e_write_dest_m(e_write_dest_m_w),
    .e_write_cpsr(e_write_cpsr_w),

    .e_do_cycle(e_do_cycle_w),
    .e_m_ma_cycle(e_m_ma_cycle_w),

    .a(a_w),
    .b(b_w),
    .c(c_w),
    .d(d_w),
    .opcode(opcode_w),
    .type(type_w));

  arithmetic_logic_unit alu (
    .clk(clk),
    .a(a_w),
    .b(b_w),
    .cpsr(cpsr_i),
    .opcode(opcode_w),
    .result(result_w));

  multiplier m(
    .clk(clk),
    .a(a_w),
    .b(b_w),
    .c(c_w),
    .d(d_w),
    .type(type_w),
    .result(m_result_w));

  initial begin
    rw_i_i = 6'b0;
    rw_i = 32'b0;
    cpsr_i = 32'b0;
    write = 1'b0;
    size = 2'b10;
    prot = 2'b10;
    trans = 2'b11;
    dest = 4'b0;
    write_dest_do = 1'b0;
    write_dest_m = 1'b0;
    write_cpsr = 1'b0;
    addr_reg = 32'b0;
    write_reg = 1'b0;
    size_reg = 1'b0;
    prot_reg = 2'b0;
    trans_reg = 2'b0;
  end

  always @ (posedge clk) begin
    write_reg <= write;
    trans_reg <= trans;

    if (e_exec_w) begin
      write_dest_do <= e_write_dest_do_w;
      write_dest_m <= e_write_dest_m_w;
      write_cpsr <= e_write_cpsr_w;
      if (e_do_cycle_w) begin // Data operation.
        trans <= 2'b11;
        dest <= e_dest_w;
      end
      else if (e_m_ma_cycle_w) begin // Multiply or multiply accumulate.
        trans <= 2'b11;
        dest <= e_dest_w;
      end
      else begin // No operation.
        trans <= 2'b11;
      end
    end
    else begin
      trans <= 2'b11;
      write <= 1'b0;
    end

    if (write_dest_do) begin
      rw_i_i <= dest;
      rw_i <= result_w;
    end
    else if (write_dest_m) begin
      rw_i_i <= dest;
      rw_i <= m_result_w;
    end
    else if (write_cpsr) begin
      cpsr_i <= result_w;
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

  initial begin
    result = 32'b0;
  end

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
        result[30] <= !(a + ~b + 32'b1);
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

  initial begin
    result = 32'b0;
  end

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
