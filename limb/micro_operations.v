`ifndef MICRO_OPERATIONS_V
`define MICRO_OPERATIONS_V

// UOP classes.
`define UOP_BRANCH      3'd1
`define UOP_INTEGER     3'd2
`define UOP_INTEGER_M   3'd3
`define UOP_LOAD        3'd4
`define UOP_STORE       3'd5
`define UOP_FP          3'd6

// UOP bit positions.
`define UOP_VALID_B     63
`define UOP_CLASS_MSB   62
`define UOP_CLASS_LSB   60

`endif
