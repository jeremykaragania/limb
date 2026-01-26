`ifndef MICRO_OPERATIONS_V
`define MICRO_OPERATIONS_V

// UOP classes.
`define UOP_BRANCH      4'd1
`define UOP_INTEGER     4'd2
`define UOP_INTEGER_M   4'd3
`define UOP_LOAD        4'd4
`define UOP_STORE       4'd5
`define UOP_FP          4'd6

// UOP bit positions.
`define UOP_VALID_B     63
`define UOP_CLASS_MSB   62
`define UOP_CLASS_LSB   61

`endif
