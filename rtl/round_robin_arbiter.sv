module round_robin_arbiter #(
  parameter  S_DATA_COUNT = 2,
             M_DATA_COUNT = 3,
  localparam T_ID___WIDTH = $clog2(S_DATA_COUNT)
) (
  input  logic                    clk_i,
  input  logic                    rst_in,
    
  input  logic [S_DATA_COUNT-1:0] requests_mask_i,
  output logic [T_ID___WIDTH-1:0] id_o,

  input  logic [S_DATA_COUNT-1:0] last_i, 
  output logic                    ready_o
);

  logic [S_DATA_COUNT-1 : 0] last_mask;
  logic [S_DATA_COUNT-1 : 0] crnt_mask;
  logic [S_DATA_COUNT-1 : 0] used_mask;
  logic [S_DATA_COUNT-1 : 0] list_of_mask [S_DATA_COUNT-1:0]; 

  logic [T_ID___WIDTH-1 : 0] used_mask_high_bit;
  logic [T_ID___WIDTH-1 : 0] crnt_mask_high_bit;

  logic [T_ID___WIDTH-1 : 0] ptr_wr_list;
  logic [T_ID___WIDTH-1 : 0] ptr_rd_list;
  logic [T_ID___WIDTH-1 : 0] ptr_rd_mask;

  logic is_new_mask;
  logic is_empty_mask;
  logic is_last; 
  logic is_empty;

  assign is_new_mask   = (crnt_mask != last_mask);
  assign is_empty_mask = ~|used_mask;
  assign is_last       = is_last_i[data_o];
  assign is_empty      = (ptr_wr_list == ptr_rd_list);
  assign data_o        = ptr_rd_mask; 
  assign crnt_mask     = requests_mask_i;

  always @(posedge clk_i) begin
    if (!rst_in) last_mask <= '0;
    else        last_mask <= crnt_mask;
  end

  always_ff @(posedge clk_i) begin
    if      (!rst_in)  used_mask              <= 'd0;
    else if (is_last) used_mask[ptr_rd_mask] <= 'd0;
    else              used_mask              <= list_of_mask[ptr_rd_list];
  end

  always_comb begin
    for (int i = $low(used_mask); i < $high(used_mask); i++) begin
      if (used_mask[i]) begin
        used_mask_high_bit = i;  
        break;
      end
    end
  end   

  always_comb begin
    for (int i = $low(crnt_mask); i < $high(crnt_mask); i++) begin
      if (crnt_mask[i]) begin
        crnt_mask_high_bit = i; 
        break;
      end
    end
  end   

  always_ff @(posedge clk_i) begin
    if      (!rst_in)                                                           ptr_rd_list <= 'd0;
    else if (is_new_mask && is_empty_mask) if (ptr_rd_list < S_DATA_COUNT - 1)  ptr_rd_list <= ptr_rd_list + 'd1;
                                           else                                 ptr_rd_list <= 'd0;
  end

  always_ff @(posedge clk_i) begin
    if      (!rst_in)                                         ptr_wd_list <= 'd0;
    else if (is_new_mask) if (ptr_wr_list < S_DATA_COUNT - 1) ptr_wr_list <= ptr_wr_list + 'd1;
                          else                                ptr_wr_list <= 'd0;
  end

  always_ff @(posedge clk_i) begin
    if      (!rst_in)                   ptr_rd_mask <= 'd0;
    else if (is_last && !is_empty_mask) ptr_rd_mask <= used_mask_high_bit;
    else if (is_empty || is_empty_mask) ptr_rd_mask <= crnt_mask_high_bit;
  end

  assign arbiter_ready_o = !is_empty;
  assign m_id_o          = ptr_rd_mask;
  
endmodule 