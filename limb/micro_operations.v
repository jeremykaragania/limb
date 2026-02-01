`ifndef MICRO_OPERATIONS_V
`define MICRO_OPERATIONS_V

// UOP classes.
`define UOP_BRANCH        3'd1
`define UOP_INTEGER       3'd2
`define UOP_INTEGER_M     3'd3
`define UOP_LOAD          3'd4
`define UOP_STORE         3'd5
`define UOP_FP            3'd6

// UOP bit positions.
`define UOP_VALID_B       63
`define UOP_CLASS_MSB     62
`define UOP_CLASS_LSB     60
`define UOP_COND_MSB      59
`define UOP_COND_LSB      56

// UOP integer class types.
`define UOP_REG           3'd0
`define UOP_IMM           3'd1
`define UOP_SHIFT_LSL     3'd2
`define UOP_SHIFT_LSR     3'd3
`define UOP_SHIFT_ASR     3'd4
`define UOP_SHIFT_ROR     3'd5
`define UOP_SHIFT_RRX     3'd6

// Integer class bit positions.
`define UOP_I_S_B         55    // Update flags.

`define UOP_I_OPCODE_MSB  54    // Opcode.
`define UOP_I_OPCODE_LSB  51

`define UOP_I_TYPE_MSB    50    // Type (register, immediate, shift).
`define UOP_I_TYPE_LSB    48

`define UOP_I_DST_0_MSB   47    // Destination register.
`define UOP_I_DST_0_LSB   44

`define UOP_I_SRC_0_MSB   43    // Source register 0.
`define UOP_I_SRC_0_LSB   40

`define UOP_I_SRC_1_MSB   39    // Source register 1 (valid if register or shift type).
`define UOP_I_SRC_1_LSB   35

`define UOP_I_SRC_2_MSB   34    // Source register 2 (valid if shift type).
`define UOP_I_SRC_2_LSB   31

`define UOP_I_IMM_12_MSB  39    // Immediate register (valid if immediate type).
`define UOP_I_IMM_12_LSB  28

`endif
