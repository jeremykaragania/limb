`ifndef INSTRUCTION_CACHE_V
`define INSTRUCTION_CACHE_V

// l1_instruction_cache is an L1 32KB 2-way set-associative instruction cache
// with 64 bytes cache line and an LRU replacement policy. It returns up to
// three instrucitons at a time and only word access is allowed.
//
// There are 256 lines per way, and 16 words in a line. The tag is 18 bits,
// index 8 bits, and the offset is 6 bits.
module l1_instruction_cache (
  input clk,
  input rst,

  input [31:0] addr,
  input data_valid,

  input [31:0] data,

  output reg [31:0] req_addr,
  output reg write,
  output [1:0] trans,

  output reg stall_o,
  output reg instrs_valid_o,
  output reg [1:0] instrs_count_o,
  output reg [95:0] instrs_o);

  // Way data lines.
  reg [511:0] way_data [0:1][0:255];

  // Way tags.
  reg [17:0] way_tag [0:1][0:255];

  // Way tag validity.
  reg way_valid [0:1][0:255];

  // Way LRU bits.
  reg lru_data [0:255];

  // Replacement policy stuff.
  reg [3:0] refill_offset;
  reg eviction_active;
  reg req_active;

  assign trans = req_active ? 2'b10 : 2'd0;

  // Bit extraction.
  wire [17:0] tag = addr[31:14];
  wire [7:0] index = addr[13:6];
  wire [5:0] offset = addr[5:0];

  wire match_way_0 = way_tag[0][index] == tag;
  wire match_way_1 = way_tag[1][index] == tag;

  wire hit_way_0 = match_way_0 && way_valid[0][index];
  wire hit_way_1 = match_way_1 && way_valid[1][index];
  wire cache_hit = hit_way_0 | hit_way_1;

  wire hit_way = hit_way_0 ? 1'b0 : 1'b1;
  wire victim_way = lru_data[index];

  integer i;

  initial begin
    req_active = 1'b0;

    refill_offset = 4'b0;
    eviction_active = 1'b0;

    for (i = 0; i < 256; ++i) begin
      way_data[0][i] = 256'b0;
      way_data[1][i] = 256'b0;

      way_tag[0][i] = 18'b0;
      way_tag[1][i] = 18'b0;

      way_valid[0][i] = 1'b0;
      way_valid[1][i] = 1'b0;

      lru_data[i] = 1'b0;
    end
  end

  always @ (posedge clk) begin
    // Reset.
    if (rst) begin
      req_addr <= 32'b0;
      instrs_valid_o <= 1'b0;
      instrs_count_o <= 2'b0;
      instrs_o <= 96'b0;
      stall_o <= 1'b0;
      write <= 1'b0;
      eviction_active <= 1'b0;
    end
    // Eviction.
    else if (eviction_active) begin
      // There is valid data that we have requested, refill the victim cache
      // line at the appropriate offset with received data.
      if (data_valid && req_active) begin
        case (refill_offset)
          4'd0: way_data[victim_way][index][31:0] <= data;
          4'd1: way_data[victim_way][index][63:32] <= data;
          4'd2: way_data[victim_way][index][95:64] <= data;
          4'd3: way_data[victim_way][index][127:96] <= data;
          4'd4: way_data[victim_way][index][159:128] <= data;
          4'd5: way_data[victim_way][index][191:160] <= data;
          4'd6: way_data[victim_way][index][223:192] <= data;
          4'd7: way_data[victim_way][index][255:224] <= data;
          4'd8: way_data[victim_way][index][287:256] <= data;
          4'd9: way_data[victim_way][index][319:288] <= data;
          4'd10: way_data[victim_way][index][351:320] <= data;
          4'd11: way_data[victim_way][index][383:352] <= data;
          4'd12: way_data[victim_way][index][415:384] <= data;
          4'd13: way_data[victim_way][index][447:416] <= data;
          4'd14: way_data[victim_way][index][479:448] <= data;
          4'd15: begin
            way_data[victim_way][index][511:480] <= data;
            way_tag[victim_way][index] <= tag;
            way_valid[victim_way][index] <= 1'b1;
            lru_data[index] <= 1'b1;

            req_active <= 1'b0;
            eviction_active <= 1'b0;
            stall_o <= 1'b0;
          end
        endcase

        // End the memory request.
        req_active <= 1'b0;
        refill_offset <= refill_offset + 4'b1;
        req_addr <= req_addr + 6'd4;
      end
      else begin
        req_active <= 1'b1;
      end
    end
    // Cache hit.
    else if (cache_hit) begin
      instrs_valid_o <= 1'b1;

      case (offset)
        6'd0: begin
          instrs_o <= {way_data[hit_way][index][95:64], way_data[hit_way][index][63:32], way_data[hit_way][index][31:0]};
          instrs_count_o <= 2'd3;
        end
        6'd4: begin
          instrs_o <= {way_data[hit_way][index][127:96], way_data[hit_way][index][95:64], way_data[hit_way][index][63:32]};
          instrs_count_o <= 2'd3;
        end
        6'd8: begin
          instrs_o <= {way_data[hit_way][index][159:128], way_data[hit_way][index][127:96], way_data[hit_way][index][95:64]};
          instrs_count_o <= 2'd3;
        end
        6'd12: begin
          instrs_o <= {way_data[hit_way][index][191:160], way_data[hit_way][index][159:128], way_data[hit_way][index][127:96]};
          instrs_count_o <= 2'd3;
        end
        6'd16: begin
          instrs_o <= {way_data[hit_way][index][223:192], way_data[hit_way][index][191:160], way_data[hit_way][index][159:128]};
          instrs_count_o <= 2'd3;
        end
        6'd20: begin
          instrs_o <= {way_data[hit_way][index][255:224], way_data[hit_way][index][223:192], way_data[hit_way][index][191:160]};
          instrs_count_o <= 2'd3;
        end
        6'd24: begin
          instrs_o <= {way_data[hit_way][index][287:256], way_data[hit_way][index][255:224], way_data[hit_way][index][223:192]};
          instrs_count_o <= 2'd3;
        end
        6'd28: begin
          instrs_o <= {way_data[hit_way][index][319:288], way_data[hit_way][index][287:256], way_data[hit_way][index][255:224]};
          instrs_count_o <= 2'd3;
        end
        6'd32: begin
          instrs_o <= {way_data[hit_way][index][351:320], way_data[hit_way][index][319:288], way_data[hit_way][index][287:256]};
          instrs_count_o <= 2'd3;
        end
        6'd36: begin
          instrs_o <= {way_data[hit_way][index][383:352], way_data[hit_way][index][351:320], way_data[hit_way][index][319:288]};
          instrs_count_o <= 2'd3;
        end
        6'd40: begin
          instrs_o <= {way_data[hit_way][index][415:384], way_data[hit_way][index][383:352], way_data[hit_way][index][351:320]};
          instrs_count_o <= 2'd3;
        end
        6'd44: begin
          instrs_o <= {way_data[hit_way][index][447:416], way_data[hit_way][index][415:384], way_data[hit_way][index][383:352]};
          instrs_count_o <= 2'd3;
        end
        6'd48: begin
          instrs_o <= {way_data[hit_way][index][479:448], way_data[hit_way][index][447:416], way_data[hit_way][index][415:384]};
          instrs_count_o <= 2'd3;
        end
        6'd52: begin
          instrs_o <= {way_data[hit_way][index][511:480], way_data[hit_way][index][479:448], way_data[hit_way][index][447:416]};
          instrs_count_o <= 2'd3;
        end
        6'd56: begin
          instrs_o <= {way_data[hit_way][index][511:480], way_data[hit_way][index][479:448]};
          instrs_count_o <= 2'd2;
        end
        6'd60: begin
          instrs_o <= {way_data[hit_way][index][511:480]};
          instrs_count_o <= 2'd1;
        end
      endcase
    end
    // Cache miss.
    else begin
      refill_offset <= 4'b0;

      req_addr <= {tag, index, 6'b0};
      req_active <= 1'b1;
      eviction_active <= 1'b1;
      stall_o <= 1'b1;
      instrs_valid_o <= 1'b0;
    end
  end
endmodule

`endif
