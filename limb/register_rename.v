`ifndef REGISTER_RENAME
`define REGISTER_RENAME

`include "micro_operations.v"

module remap_file (
  input clk,
  input rst,

  input [3:0] reg_0_i,
  input [3:0] reg_1_i,
  input [3:0] reg_2_i,

  output reg [5:0] tag_0_o,
  output reg [5:0] tag_1_o,
  output reg [5:0] tag_2_o
  );

  reg [5:0] map [0:14];

  integer i;

  always @ (*) begin
    if (rst) begin
      for (i = 0; i < 15; ++i) begin
        map[i] = i;
      end
    end
    else begin
      tag_0_o = map[reg_0_i];
      tag_1_o = map[reg_1_i];
      tag_2_o = map[reg_2_i];
    end
  end

endmodule

module register_rename (
  input clk,
  input rst,

  input [2:0][63:0] uops_i,

  output reg [2:0][63:0] uops_o);

  wire [63:0] uop_0 = uops_i[0];
  wire [63:0] uop_1 = uops_i[1];
  wire [63:0] uop_2 = uops_i[2];

  wire uop_0_valid = uop_0[`UOP_VALID_B];
  wire uop_1_valid = uop_1[`UOP_VALID_B];
  wire uop_2_valid = uop_2[`UOP_VALID_B];

  wire [2:0] uop_0_class = uop_0[`UOP_CLASS_MSB:`UOP_CLASS_LSB];
  wire [2:0] uop_1_class = uop_1[`UOP_CLASS_MSB:`UOP_CLASS_LSB];
  wire [2:0] uop_2_class = uop_2[`UOP_CLASS_MSB:`UOP_CLASS_LSB];

  wire [3:0] uop_0_dst_0 = uop_0[`UOP_I_DST_0_MSB:`UOP_I_DST_0_LSB];
  wire [3:0] uop_0_src_0 = uop_0[`UOP_I_SRC_0_MSB:`UOP_I_SRC_0_LSB];
  wire [3:0] uop_0_src_1 = uop_0[`UOP_I_SRC_1_MSB:`UOP_I_SRC_1_LSB];
  wire [3:0] uop_0_src_2 = uop_0[`UOP_I_SRC_2_MSB:`UOP_I_SRC_2_LSB];

  wire [3:0] uop_1_dst_0 = uop_1[`UOP_I_DST_0_MSB:`UOP_I_DST_0_LSB];
  wire [3:0] uop_1_src_0 = uop_1[`UOP_I_SRC_0_MSB:`UOP_I_SRC_0_LSB];
  wire [3:0] uop_1_src_1 = uop_1[`UOP_I_SRC_1_MSB:`UOP_I_SRC_1_LSB];
  wire [3:0] uop_1_src_2 = uop_1[`UOP_I_SRC_2_MSB:`UOP_I_SRC_2_LSB];

  wire [3:0] uop_2_dst_0 = uop_2[`UOP_I_DST_0_MSB:`UOP_I_DST_0_LSB];
  wire [3:0] uop_2_src_0 = uop_2[`UOP_I_SRC_0_MSB:`UOP_I_SRC_0_LSB];
  wire [3:0] uop_2_src_1 = uop_2[`UOP_I_SRC_1_MSB:`UOP_I_SRC_1_LSB];
  wire [3:0] uop_2_src_2 = uop_2[`UOP_I_SRC_2_MSB:`UOP_I_SRC_2_LSB];

  integer i;

  always @ (*) begin

    if (rst) begin
      for (i = 0; i < 3; ++i) begin
        uops_o[i] = 64'b0;
      end
    end
    else begin
    end
  end

endmodule

`endif
