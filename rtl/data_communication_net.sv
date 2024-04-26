/*
  DESCRIPTION
*/
/*
  Given module is used to connect input with output.
  
  Important role has a grant_i bus are coming from 
  arbiters unit. Each cell of grant signal say
  which master (value of cell) will be connect to
  slave (number of cell).

  Besides using grant cells in other logic,
  is being checked its values when set valid signal.
  It's needed because grant signal on non-working
  slave-devices has X state. To avoid undesirable
  setting valid to 1 and passing corresponding master data
  was added condition. It check that master whose id was set on X slave
  indeed want to communicate with him: s_dest_i(grant_i[i]) == i 
*/

`timescale 1ns / 1ps

module data_communication_net #(
  parameter  T_DATA_WIDTH = 8,
             S_DATA_COUNT = 2,
             M_DATA_COUNT = 3,
             T_ID___WIDTH = $clog2(S_DATA_COUNT), 
             T_DEST_WIDTH = $clog2(M_DATA_COUNT)
) (
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
  input  logic [M_DATA_COUNT-1:0] m_ready_i,
// intermediate modules signals
  input  logic [T_ID___WIDTH-1:0] grant_i  [M_DATA_COUNT-1:0]
);

  always_comb begin
    for (int s_idx = 0; s_idx < M_DATA_COUNT; s_idx++) begin
      m_id_o   [s_idx]  = grant_i[s_idx];
      m_data_o [s_idx]  = s_data_i[grant_i[s_idx]];
      m_valid_o[s_idx]  = (s_dest_i[grant_i[s_idx]] == s_idx) && s_valid_i[grant_i[s_idx]];
      m_last_o [s_idx]  = s_last_i[grant_i[s_idx]];
    end 
    for (int m_idx = 0; m_idx < S_DATA_COUNT; m_idx++) begin
      s_ready_o[m_idx] = m_valid_o[s_dest_i[m_idx]] && m_ready_i[s_dest_i[m_idx]];
    end 
  end

endmodule