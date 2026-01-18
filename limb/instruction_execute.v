`ifndef INSTRUCTION_EXECUTE_V
`define INSTRUCTION_EXECUTE_V

module instruction_execute (
  input clk,
  input rst,

  input exec_i,

  input [3:0] dest_i,

  input write_dest_do_i,
  input write_dest_m_i,
  input write_cpsr_i,

  input [31:0] do_cycle_i,
  input [31:0] m_ma_cycle_i,

  input [31:0] a_i,
  input [31:0] b_i,
  input [31:0] c_i,
  input [31:0] d_i,
  input [3:0] opcode_i,
  input [2:0] type_i,

  input [31:0] cpsr_i,

  output reg [3:0] dest_o,

  output reg write_dest_do_o,
  output reg write_dest_m_o,
  output reg write_cpsr_o,

  output reg write_o,
  output reg [1:0] trans_o,

  output [31:0] result_o,
  output [63:0] m_result_o);

  arithmetic_logic_unit alu (
    .clk(clk),
    .rst(rst),
    .a(a_i),
    .b(b_i),
    .cpsr(cpsr_i),
    .opcode(opcode_i),
    .result(result_o));

  multiplier m(
    .clk(clk),
    .rst(rst),
    .a(a_i),
    .b(b_i),
    .c(c_i),
    .d(d_i),
    .type(type_i),
    .result(m_result_o));

  always @ (posedge clk) begin
    if (rst) begin
      dest_o <= 4'b0;

      write_dest_do_o <= 1'b0;
      write_dest_m_o <= 1'b0;
      write_cpsr_o <= 1'b0;

      write_o <= 1'b0;
      trans_o <= 2'b0;
    end
    if (exec_i) begin
      write_dest_do_o <= write_dest_do_i;
      write_dest_m_o <= write_dest_m_i;
      write_cpsr_o <= write_cpsr_i;

      if (do_cycle_i) begin // Data operation.
        trans_o <= 2'b11;
        dest_o <= dest_i;
      end
      else if (m_ma_cycle_i) begin // Multiply or multiply accumulate.
        trans_o <= 2'b11;
        dest_o <= dest_i;
      end
      else begin // No operation.
        trans_o <= 2'b11;
      end
    end
    else begin
      trans_o <= 2'b11;
      write_o <= 1'b0;
    end
  end
endmodule

module arithmetic_logic_unit (
  input clk,
  input rst,
  input [31:0] a,
  input [31:0] b,
  input [31:0] cpsr,
  input [0:3] opcode,
  output reg [31:0] result);

  always @ (posedge clk) begin
    if (rst) begin
      result <= 32'b0;
    end
    else begin
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
  end
endmodule

module multiplier(
  input clk,
  input rst,
  input [31:0] a,
  input [31:0] b,
  input [31:0] c,
  input [31:0] d,
  input [2:0] type,
  output reg [63:0] result);

  always @ (posedge clk) begin
    if (rst) begin
      result <= 64'b0;
    end
    else begin
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
  end
endmodule

`endif
