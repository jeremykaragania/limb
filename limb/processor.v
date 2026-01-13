`include "instruction_fetch.v"
`include "instruction_decode.v"
`include "instruction_execute.v"
`include "write_back.v"

module memory_controller (
  input clk,
  input [31:0] addr,
  input [31:0] wdata,
  output reg [31:0] rdata,
  output reg abort,
  output reg data_valid,
  input write,
  input size,
  input [1:0] prot,
  input[1:0] trans);

  reg [7:0] memory [0:8191];

  initial begin
    $readmemh(".memory", memory);
  end

  always @ (posedge clk) begin
    if (trans == 2'b10 || trans == 2'b11) begin
      data_valid <= 1'b1;
      case (write)
        0: begin
          rdata <= {memory[addr+3], memory[addr+2], memory[addr+1], memory[addr]};
        end
        1: begin
          {memory[addr+3], memory[addr+2], memory[addr+1], memory[addr]} <= wdata;
        end
      endcase
    end
    else begin
      data_valid <= 1'b0;
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

module processor (
  input clk,
  input n_reset,

  // Memory interface.
  output [31:0] addr,
  output [31:0] wdata,
  input [31:0] rdata,
  input data_valid,
  input abort,
  output write,
  output size,
  output [1:0] prot,
  output [1:0] trans);

  // Register file.
  wire [5:0] rw_i_i_w;
  wire [31:0] rw_i_w;
  wire [31:0] cpsr_i_w;
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

  // Register writeback.
  wire [3:0] dest;
  wire write_dest_do;
  wire write_dest_m;
  wire write_cpsr;

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

  register_file rf_m (
    .clk(clk),
    .rw_i_i(rw_i_i_w),
    .rw_i(rw_i_w),
    .cpsr_i(cpsr_i_w),

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

    .result_i(result_w),

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

  instruction_execute ie_m (
    .clk(clk),

    .exec_i(e_exec_w),

    .dest_i(e_dest_w),

    .write_dest_do_i(e_write_dest_do_w),
    .write_dest_m_i(e_write_dest_m_w),
    .write_cpsr_i(e_write_cpsr_w),

    .do_cycle_i(e_do_cycle_w),
    .m_ma_cycle_i(e_m_ma_cycle_w),

    .a_i(a_w),
    .b_i(b_w),
    .c_i(c_w),
    .d_i(d_w),
    .opcode_i(opcode_w),
    .type_i(type_w),

    .cpsr_i(cpsr_i_w),

    .dest_o(dest),

    .write_dest_do_o(write_dest_do),
    .write_dest_m_o(write_dest_m),
    .write_cpsr_o(write_cpsr),

    .write_o(write),
    .trans_o(trans),

    .result_o(result_w),
    .m_result_o(m_result_w));

  write_back wb_m (
  .clk(clk),

  .dest_i(dest),

  .write_dest_do_i(write_dest_do),
  .write_dest_m_i(write_dest_m),
  .write_cpsr_i(write_cpsr),

  .result_i(result_w),
  .m_result_i(m_result_w),

  .rw_i_o(rw_i_i_w),
  .rw_o(rw_i_w),
  .cpsr_o(cpsr_i_w));
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
