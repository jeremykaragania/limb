`ifndef MICRO_OPERATIONS_V
`define MICRO_OPERATIONS_V

// UOP classes.
`define UOP_BRANCH            3'd1
`define UOP_INTEGER           3'd2
`define UOP_INTEGER_M         3'd3
`define UOP_LOAD              3'd4
`define UOP_STORE             3'd5
`define UOP_FP                3'd6

// UOP bit positions.
`define UOP_VALID_B           63
`define UOP_CLASS_MSB         62
`define UOP_CLASS_LSB         60
`define UOP_COND_MSB          59
`define UOP_COND_LSB          56

// UOP integer class types.
`define UOP_REG               3'd0
`define UOP_IMM               3'd1
`define UOP_SHIFT_LSL         3'd2
`define UOP_SHIFT_LSR         3'd3
`define UOP_SHIFT_ASR         3'd4
`define UOP_SHIFT_ROR         3'd5
`define UOP_SHIFT_RRX         3'd6

// Integer class bit positions.
`define UOP_I_S_B             55    // Update flags.

`define UOP_I_OPCODE_MSB      54    // Opcode.
`define UOP_I_OPCODE_LSB      51

`define UOP_I_TYPE_MSB        50    // Type (register, immediate, shift).
`define UOP_I_TYPE_LSB        48

`define UOP_I_DST_0_VALID_B   47    // Destination register valid.

`define UOP_I_DST_0_MSB       46    // Destination register.
`define UOP_I_DST_0_LSB       43

`define UOP_I_SRC_0_MSB       42    // Source register 0.
`define UOP_I_SRC_0_LSB       39

`define UOP_I_SRC_1_MSB       38    // Source register 1 (valid if register or shift type).
`define UOP_I_SRC_1_LSB       34

`define UOP_I_SRC_2_MSB       33    // Source register 2 (valid if shift type).
`define UOP_I_SRC_2_LSB       30

`define UOP_I_IMM_12_MSB      38    // Immediate register (valid if immediate type).
`define UOP_I_IMM_12_LSB      27

`define UOP_I_DST_P_0_MSB     26    // Physical destination register.
`define UOP_I_DST_P_0_LSB     21

`define UOP_I_SRC_P_0_MSB     20    // Physical source register 1.
`define UOP_I_SRC_P_0_LSB     15

`define UOP_I_SRC_P_1_MSB     14    // Physical source register 2.
`define UOP_I_SRC_P_1_LSB     9

`define UOP_I_SRC_P_2_MSB     8     // Physical source register 3.
`define UOP_I_SRC_P_2_LSB     3

`endif
