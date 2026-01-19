`ifndef INSTRUCTION_DECODE_V
`define INSTRUCTION_DECODE_V

`define AL 4'b1110
`define NOP 28'b0011001000001111000000000000

// UOP classes.
`define UOP_BRANCH 4'd1
`define UOP_INTEGER 4'd2
`define UOP_INTEGER_M 4'd3
`define UOP_LOAD 4'd4
`define UOP_STORE 4'd5
`define UOP_FP 4'd6

module instruction_decode (
  input clk,

  input [31:0] instr_i,

  input [31:0] result_i,

  input [31:0] rr1_i,
  input [31:0] rr2_i,
  input [31:0] rr3_i,
  input [31:0] rr4_i,

  output reg [5:0] rr1_i_o,
  output reg [5:0] rr2_i_o,
  output reg [5:0] rr3_i_o,
  output reg [5:0] rr4_i_o,

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

  reg e_oprnd2_t;
  reg [31:0] cpsr;
  reg [3:0] uop_class;

  // Condition.
  wire [3:0] cond = instr_i[31:28];

  // Data processing.
  wire [3:0] dp_opcode = instr_i[24:21];
  wire [3:0] dp_rn = instr_i[19:16];
  wire [3:0] dp_rd = instr_i[15:12];
  wire [3:0] dp_oprnd_2 = instr_i[11:0];

  // Multiply.
  wire [3:0] m_rd = instr_i[19:16];
  wire [3:0] m_rn = instr_i[15:12];
  wire [3:0] m_rs = instr_i[11:8];
  wire [3:0] m_rm = instr_i[3:0];

  // Multiply long.
  wire [3:0] ml_rd_hi = instr_i[19:16];
  wire [3:0] ml_rn_lo = instr_i[15:12];
  wire [3:0] ml_rn = instr_i[11:8];
  wire [3:0] ml_rm = instr_i[3:0];

  // Branch exchange.
  wire [3:0] be_rn = instr_i[3:0];

  // Single data transfer.
  wire [3:0] sdt_rn = instr_i[19:16];
  wire [3:0] sdt_rd = instr_i[15:12];
  wire [11:0] sdt_offset = instr_i[11:0];

  // Branch.
  wire [23:0] b_offset = instr_i[23:0];

  initial begin
    e_oprnd2_t = 1'b0;
    cpsr = 32'b0;
  end

  always @ (*) begin
    if (instr_i[27:0] == `NOP) begin // No operation.
      e_do_cycle = 1'b0;
      e_write_dest_do = 1'b0;
      e_write_dest_m = 1'b0;
      e_write_cpsr = 1'b0;
    end
    else if (!instr_i[25] && instr_i[7] && instr_i[4]) begin // Multiply or multiply accumulate.
      uop_class = `UOP_INTEGER_M;
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
      uop_class = `UOP_INTEGER;
      e_do_cycle = 1'b1;
      e_oprnd2_t = instr_i[25];
      e_oprnd2 = instr_i[11:0];
      opcode = instr_i[24:21];
      rr1_i_o = instr_i[19:16];
      rr2_i_o = e_oprnd2;

      /*
        If the first register being read hasn't been written yet, forward the
        result from the instruction execution module.
      */
      if (e_exec && e_dest == rr1_i_o) begin
        a = result_i;
      end
      else begin
        a = rr1_i;
      end

      /*
        If the second register being read hasn't been written yet, forward the
        result from the instruction execution module.
      */
      if (e_exec && e_dest == rr2_i_o) begin
        b = result_i;
      end
      else begin
        b = instr_i[25] ? instr_i[11:0] : rr2_i;
      end

      e_dest = instr_i[15:12];

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

    case (cond)
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

`endif
