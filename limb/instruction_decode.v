`ifndef INSTRUCTION_DECODE_V
`define INSTRUCTION_DECODE_V

`include "instructions.v"
`include "micro_operations.v"

module instruction_decode (
  input clk,
  input rst,

  input instr_valid_i,
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
  output reg [2:0] type,

  output reg [63:0] uop_o
  );

  reg [31:0] cpsr;

  // Condition.
  wire [3:0] cond = instr_i[31:28];

  // Data processing.
  wire [3:0] dp_opcode = instr_i[24:21];
  wire [3:0] dp_rn = instr_i[19:16];
  wire [3:0] dp_rd = instr_i[15:12];
  wire [3:0] dp_rs = instr_i[11:8];
  wire [3:0] dp_rm = instr_i[3:0];
  wire [11:0] dp_oprnd_2 = instr_i[11:0];
  wire [4:0] dp_imm_5 = instr_i[11:7];
  wire [1:0] dp_shift_type = instr_i[6:5];
  wire dp_oprnd_2_t = instr_i[25];

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
    cpsr = 32'b0;
  end

  always @ (*) begin
    if (rst) begin
      rr1_i_o <= 6'b0;
      rr2_i_o <= 6'b0;
      rr3_i_o <= 6'b0;
      rr4_i_o <= 6'b0;

      e_exec <= 1'b0;
      e_oprnd2 <= 12'b0;
      e_dest <= 4'b0;

      e_write_dest_do <= 1'b0;
      e_write_dest_m <= 1'b0;
      e_write_cpsr <= 1'b0;

      e_do_cycle <= 32'b0;
      e_m_ma_cycle <= 32'b0;

      a <= 32'b0;
      b <= 32'b0;
      c <= 32'b0;
      d <= 32'b0;
      opcode <= 4'b0;
      type <= 3'b0;
    end
    else if (instr_valid_i) begin
      uop_o = 64'b0;
      uop_o[`UOP_COND_MSB:`UOP_COND_LSB] = cond;

      if (instr_i[27:26] == 2'b00) begin // Data processing or miscellaneous instruction.
        uop_o[`UOP_VALID_B] = 1'b1;

        if (instr_i[25]) begin
          if (!instr_i[24] || instr_i[23] || instr_i[20]) begin // Data processing (immediate).
            uop_o[`UOP_CLASS_MSB:`UOP_CLASS_LSB] = `UOP_INTEGER;
            uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_IMM;
            uop_o[`UOP_I_IMM_12_MSB:`UOP_I_IMM_12_LSB] = dp_oprnd_2;

            uop_o[`UOP_I_SRC_0_MSB:`UOP_I_SRC_0_LSB] = dp_rn;
            uop_o[`UOP_I_DST_0_MSB:`UOP_I_DST_0_LSB] = dp_rd;

            if (dp_opcode != `OP_CMP && dp_opcode != `OP_CMN && dp_opcode != `OP_TST && dp_opcode != `OP_TEQ) begin
              uop_o[`UOP_I_DST_0_MSB:`UOP_I_DST_0_LSB] = dp_rd;
              uop_o[`UOP_I_DST_0_VALID_B] = 1'b1;
            end
          end
          else if (instr_i[24] && !instr_i[23] && instr_i[21] && !instr_i[20]) begin // MSR (immediate), and hints.
            if (instr_i[22]) begin // MSR (immediate).
            end
            else begin
              if (instr_i[19:16] == 4'b0) begin
                case (instr_i[7:0])
                  8'b00000000: begin // NOP.
                    e_do_cycle = 1'b0;
                    e_write_dest_do = 1'b0;
                    e_write_dest_m = 1'b0;
                    e_write_cpsr = 1'b0;
                  end
                endcase
              end
            end
          end
        end
        else begin
          if ((!instr_i[24] || instr_i[23] || instr_i[20]) && !instr_i[4]) begin // Data processing (register).
            uop_o[`UOP_CLASS_MSB:`UOP_CLASS_LSB] = `UOP_INTEGER_M;

            case (dp_shift_type)
              `SHIFT_LSL: begin
                if (dp_imm_5) begin
                  uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_SHIFT_LSL;
                end
                else begin
                  uop_o[`UOP_CLASS_MSB:`UOP_CLASS_LSB] = `UOP_INTEGER;
                  uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_REG;
                end
              end
              `SHIFT_LSR: begin
                uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_SHIFT_LSR;
              end
              `SHIFT_ASR: begin
                uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_SHIFT_ASR;
              end
              `SHIFT_ROR: begin
                uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_SHIFT_ROR;
              end
            endcase

            uop_o[`UOP_I_SRC_0_MSB:`UOP_I_SRC_0_LSB] = dp_rn;
            uop_o[`UOP_I_SRC_1_MSB:`UOP_I_SRC_1_LSB] = dp_rm;

            if (dp_opcode != `OP_CMP && dp_opcode != `OP_CMN && dp_opcode != `OP_TST && dp_opcode != `OP_TEQ) begin
              uop_o[`UOP_I_DST_0_MSB:`UOP_I_DST_0_LSB] = dp_rd;
              uop_o[`UOP_I_DST_0_VALID_B] = 1'b1;
            end
          end
          else if (!instr_i[7] && instr_i[4]) begin // Register-shifted register.
            /*
              Unconditional register-shifted register instructions are
              multicyle while conditional ones single cycle.
            */
            if (cond == `COND_AL) begin
              uop_o[`UOP_CLASS_MSB:`UOP_CLASS_LSB] = `UOP_INTEGER_M;
            end
            else begin
              uop_o[`UOP_CLASS_MSB:`UOP_CLASS_LSB] = `UOP_INTEGER;
            end

            case (dp_shift_type)
              `SHIFT_LSL: begin
                uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_SHIFT_LSL;
              end
              `SHIFT_LSR: begin
                uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_SHIFT_LSR;
              end
              `SHIFT_ASR: begin
                uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_SHIFT_ASR;
              end
              `SHIFT_ROR: begin
                uop_o[`UOP_I_TYPE_MSB:`UOP_I_TYPE_LSB] = `UOP_SHIFT_ROR;
              end
            endcase

            uop_o[`UOP_I_SRC_0_MSB:`UOP_I_SRC_0_LSB] = dp_rn;
            uop_o[`UOP_I_SRC_1_MSB:`UOP_I_SRC_1_LSB] = dp_rm;
            uop_o[`UOP_I_SRC_2_MSB:`UOP_I_SRC_2_LSB] = dp_rs;

            if (dp_opcode != `OP_CMP && dp_opcode != `OP_CMN && dp_opcode != `OP_TST && dp_opcode != `OP_TEQ) begin
              uop_o[`UOP_I_DST_0_MSB:`UOP_I_DST_0_LSB] = dp_rd;
              uop_o[`UOP_I_DST_0_VALID_B] = 1'b1;
            end
          end
          else if (!instr_i[24] && instr_i[7:4] == 4'b1001) begin // Multiply and multiply accumulate.
            uop_o[`UOP_VALID_B] = 1'b1;
            uop_o[`UOP_CLASS_MSB:`UOP_CLASS_LSB] = `UOP_INTEGER_M;

            e_do_cycle = 1'b0;
            e_m_ma_cycle = 1'b1;
            e_dest = m_rd;
            e_write_dest_do = 1'b0;
            e_write_dest_m = !instr_i[23];
            e_write_cpsr = 1'b0;
            rr1_i_o = m_rm;
            rr2_i_o = m_rs;
            rr3_i_o = m_rd;
            rr4_i_o = m_rn;
            a = rr1_i;
            b = rr2_i;
            c = rr3_i;
            d = rr4_i;
            type = instr_i[23:21];
          end
        end

        e_do_cycle = 1'b1;
        e_oprnd2 = dp_oprnd_2;
        opcode = dp_opcode;
        rr1_i_o = dp_rn;
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
          b = instr_i[25] ? dp_oprnd_2 : rr2_i;
        end

        e_dest = instr_i[15:12];

        if (dp_opcode == `OP_CMP || dp_opcode == `OP_CMN || dp_opcode == `OP_TST || dp_opcode == `OP_TEQ) begin
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
      else if (instr_i[27:25] == 4'b011) begin // Load or store word and unsigned byte instruction.
        if (dp_opcode[0]) begin // Load.
          uop_o[`UOP_VALID_B] = 1'b1;
          uop_o[`UOP_CLASS_MSB:`UOP_CLASS_LSB] = `UOP_LOAD;
        end
        else begin // Store.
          uop_o[`UOP_VALID_B] = 1'b1;
          uop_o[`UOP_CLASS_MSB:`UOP_CLASS_LSB] = `UOP_STORE;
        end
      end
      else begin
        e_write_dest_do = 1'b0;
        e_write_dest_m = 1'b0;
        e_write_cpsr = 1'b0;
        e_exec = 1'b0;
      end

      case (cond)
        `COND_EQ: begin
          if (cpsr[30]) begin
            e_exec = 1'b1;
          end
        end
        `COND_NE: begin
          if (!cpsr[30]) begin
            e_exec = 1'b1;
          end
        end
        `COND_CS: begin
          if (cpsr[29]) begin
            e_exec = 1'b1;
          end
        end
        `COND_CC: begin
          if (!cpsr[29]) begin
            e_exec = 1'b1;
          end
        end
        `COND_MI: begin
          if (cpsr[31]) begin
            e_exec = 1'b1;
          end
        end
        `COND_PL: begin
          if (!cpsr[31]) begin
            e_exec = 1'b1;
          end
        end
        `COND_VS: begin
          if (cpsr[28]) begin
            e_exec = 1'b1;
          end
        end
        `COND_VC: begin
          if (!cpsr[28]) begin
            e_exec = 1'b1;
          end
        end
        `COND_HI: begin
          if (cpsr[29] || !cpsr[30]) begin
            e_exec = 1'b1;
          end
        end
        `COND_LS: begin
          if (!cpsr[29] || cpsr[30]) begin
            e_exec = 1'b1;
          end
        end
        `COND_GE: begin
          if (cpsr[31] == cpsr[28]) begin
            e_exec = 1'b1;
          end
        end
        `COND_LT: begin
          if (cpsr[31] != cpsr[28]) begin
            e_exec = 1'b1;
          end
        end
        `COND_GT: begin
          if (!cpsr[28] || cpsr[31] == cpsr[28]) begin
            e_exec = 1'b1;
          end
        end
        `COND_LE: begin
          if (cpsr[28] || cpsr[31] != cpsr[28]) begin
            e_exec = 1'b1;
          end
        end
        `COND_AL: begin
          e_exec = 1'b1;
        end
      endcase
    end
    else begin
      uop_o = 64'b0;
    end
  end
endmodule

`endif
