module arbiters_unit #(
  parameter  T_DATA_WIDTH = 8,
             S_DATA_COUNT = 2,
             M_DATA_COUNT = 3,
  localparam T_ID___WIDTH = $clog2(S_DATA_COUNT),
             T_DEST_WIDTH = $clog2(M_DATA_COUNT)
) (
  input  logic                      clk_i,
  input  logic                      rst_in,

  input  logic [T_DEST_WIDTH-1 : 0] s_dest_i         [S_DATA_COUNT-1 : 0],
  input  logic [S_DATA_COUNT-1 : 0] s_last_i,
  input  logic [S_DATA_COUNT-1 : 0] s_valid_i,

  output logic [T_ID___WIDTH-1 : 0] grant_o          [M_DATA_COUNT-1 : 0],
  output logic [M_DATA_COUNT-1 : 0] arbiter_ready_o
);

  logic [S_DATA_COUNT-1 : 0] requests_masks  [M_DATA_COUNT-1 : 0];

// ==================================================================
//  ROUND-ROBIN ARBITERS.
//    Receive mask of master wants to communicate to given slave
//    And return id about choosen master.
// ==================================================================
  generate 
    for (genvar i = 0; i < M_DATA_COUNT; i++) begin
      round_robin_arbiter #(
        .S_DATA_COUNT ( S_DATA_COUNT ),
        .M_DATA_COUNT ( M_DATA_COUNT )
      ) rr_arbtr_inst (
        .clk_i            ( clk_i              ),
        .rst_in           ( rst_in             ),
      
        .requests_masks_i ( requests_masks[i]  ),
        .id_o             ( grant_o[i]         ),

        .last_i           ( s_last_i           ), 
        .ready_o          ( arbiter_ready_o[i] )
      );
    end
  endgenerate

// ==================================================================
//  MASK
//    To form mask of masters wants to communicate with given slaves
// ==================================================================
  always_comb begin
    for (int i = 0; i < M_DATA_COUNT; i++) begin
      for (int j = 0; j < S_DATA_COUNT; j++) begin
        if ((s_dest_i[j] == i) && s_valid_i[j]) requests_masks[i][j] = 1'b1;
      end
    end
  end
  
endmodule