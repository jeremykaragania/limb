`ifndef INSTRUCTIONS_H
`define INSTRUCTIONS_H

// Opcodes.
`define OP_AND 4'b0000
`define OP_EOR 4'b0001
`define OP_SUB 4'b0010
`define OP_RSB 4'b0011
`define OP_ADD 4'b0100
`define OP_ADC 4'b0101
`define OP_SBC 4'b0110
`define OP_RSC 4'b0111
`define OP_TST 4'b1000
`define OP_TEQ 4'b1001
`define OP_CMP 4'b1010
`define OP_CMN 4'b1011
`define OP_ORR 4'b1100
`define OP_MOV 4'b1101
`define OP_LSL 4'b1101
`define OP_ASR 4'b1101
`define OP_RRX 4'b1101
`define OP_ROR 4'b1101
`define OP_BIC 4'b1110
`define OP_MVN 4'b1111

// Conditions.
`define COND_EQ 4'b0000
`define COND_NE 4'b0001
`define COND_CS 4'b0010
`define COND_CC 4'b0011
`define COND_MI 4'b0100
`define COND_PL 4'b0101
`define COND_VS 4'b0110
`define COND_VC 4'b0111
`define COND_HI 4'b1000
`define COND_LS 4'b1001
`define COND_GE 4'b1010
`define COND_LT 4'b1011
`define COND_GT 4'b1100
`define COND_LE 4'b1101
`define COND_AL 4'b1110

// Shifts.
`define SHIFT_LSL 2'b00
`define SHIFT_LSR 2'b01
`define SHIFT_ASR 2'b10
`define SHIFT_ROR 2'b11

`endif
