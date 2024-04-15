/*
  DESCRIPTION
*/
/*
  Nothing unusual. Just top module.

  arbiters_unit define which master will be connect to which slaves
  and their queue with the help round-robin politics if it is necassary.

  data_connection_net with the help output grant signal of arbiters_unit
  directly connect masters and slaves. 
*/

`timescale 1ns / 1ps

module stream_xbar #(
  parameter  T_DATA_WIDTH = 8,
             S_DATA_COUNT = 2,
             M_DATA_COUNT = 3,
  localparam T_ID___WIDTH = $clog2(S_DATA_COUNT),
             T_DEST_WIDTH = $clog2(M_DATA_COUNT)
) (
  input  logic                    clk,
  input  logic                    rst_n,
// multiple input streams
  input  logic [T_DATA_WIDTH-1:0] s_data_i [S_DATA_COUNT-1:0],
  input  logic [T_DEST_WIDTH-1:0] s_dest_i [S_DATA_COUNT-1:0],
  input  logic [S_DATA_COUNT-1:0] s_last_i,
  input  logic [S_DATA_COUNT-1:0] s_valid_i,
  output logic [S_DATA_COUNT-1:0] s_ready_o,
// multiple output streams
  output logic [T_DATA_WIDTH-1:0] m_data_o [M_DATA_COUNT-1:0],
  output logic [T_ID___WIDTH-1:0] m_id_o   [M_DATA_COUNT-1:0],
  output logic [M_DATA_COUNT-1:0] m_last_o,
  output logic [M_DATA_COUNT-1:0] m_valid_o,
  input  logic [M_DATA_COUNT-1:0] m_ready_i
);

  logic [T_ID___WIDTH-1 : 0] grant [M_DATA_COUNT-1 : 0];
  logic [M_DATA_COUNT-1 : 0] arbiter_ready;

  arbiters_unit #(
      .T_DATA_WIDTH ( T_DATA_WIDTH ),
      .S_DATA_COUNT ( S_DATA_COUNT ),
      .M_DATA_COUNT ( M_DATA_COUNT )
  ) arbtrs_unit_init (
      .clk_i           ( clk           ),
      .rst_in          ( rst_n         ),

      .s_dest_i        ( s_dest_i      ),
      .s_last_i        ( s_last_i      ),
      .s_valid_i       ( s_valid_i     ),

      .grant_o         ( grant         ),
      .arbiter_ready_o ( arbiter_ready )
  );

  data_communication_net #(
    .T_DATA_WIDTH ( T_DATA_WIDTH ),
    .S_DATA_COUNT ( S_DATA_COUNT ),
    .M_DATA_COUNT ( M_DATA_COUNT )
  ) comm_net_init (
    .clk_i           ( clk           ),
    .rst_in          ( rst_n         ),

    .s_data_i        ( s_data_i      ),
    .s_dest_i        ( s_dest_i      ),
    .s_last_i        ( s_last_i      ),
    .s_valid_i       ( s_valid_i     ),
    .s_ready_o       ( s_ready_o     ),

    .m_data_o        ( m_data_o      ),
    .m_id_o          ( m_id_o        ),
    .m_last_o        ( m_last_o      ),
    .m_valid_o       ( m_valid_o     ),
    .m_ready_i       ( m_ready_i     ),

    .grant_i         ( grant         ),
    .arbiter_ready_i ( arbiter_ready )
  );

endmodule