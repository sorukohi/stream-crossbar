/*
  DESCRIPTION
*/
/*
  Given module is used to connect input with output.
  
  Important role has a grant_i bus are coming from 
  arbiters unit. Each cell of grant signal say
  which master (value of cell) will be connect to
  slave (number of cell).
*/

module data_communication_net #(
  parameter  T_DATA_WIDTH = 8,
             S_DATA_COUNT = 2,
             M_DATA_COUNT = 3,
  localparam T_ID___WIDTH = $clog2(S_DATA_COUNT),
             T_DEST_WIDTH = $clog2(M_DATA_COUNT)
) (
  input  logic                    clk_i,
  input  logic                    rst_in,
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
  input  logic [T_ID___WIDTH-1:0] grant_i  [M_DATA_COUNT-1:0],
  input  logic [M_DATA_COUNT-1:0] arbiter_ready_i
);

  logic [T_ID___WIDTH-1:0] id_ff    [M_DATA_COUNT-1:0];
  logic [T_DATA_WIDTH-1:0] data_ff  [M_DATA_COUNT-1:0];
  logic [M_DATA_COUNT-1:0] valid_ff;
  logic [M_DATA_COUNT-1:0] last_ff;
  logic [S_DATA_COUNT-1:0] ready_ff;

// ===================================================
//  ID
// ===================================================

  always @(posedge clk_i) begin
    if   (!rst_in)              id_ff <= '{M_DATA_COUNT{'d0}};
    else begin
      for (int i = 0; i < M_DATA_COUNT; i++) begin
        if (arbiter_ready_i[i]) id_ff[i] = grant_i[i];
      end
    end 
  end

// ===================================================
//  DATA
// ===================================================

  always @(posedge clk_i) begin
    if (!rst_in)                  data_ff <= '{M_DATA_COUNT{'d0}};
    else begin
      for (int i = 0; i < M_DATA_COUNT; i++) begin
          if (arbiter_ready_i[i]) data_ff[i] = s_data_i[grant_i[i]];
      end
    end
  end

// ===================================================
//  VALID
// =================================================== 

  always @(posedge clk_i) begin
    if (!rst_in)                valid_ff <= 'd0;
    else begin
      for (int i = 0; i < M_DATA_COUNT; i++) begin
        if (arbiter_ready_i[i]) valid_ff[i] = s_valid_i[grant_i[i]];
      end
    end
  end

// ===================================================
//  LAST
// =================================================== 

  always_ff @(posedge clk_i) begin
    if (!rst_in)                last_ff <= 'd0;
    else begin
      for (int i = 0; i < M_DATA_COUNT; i++) begin
        if (arbiter_ready_i[i]) last_ff[i] = s_last_i[grant_i[i]];
      end
    end
  end

// ===================================================
//  READY
// ===================================================    

  always_ff @(posedge clk_i) begin
    if   (!rst_in)            ready_ff             <= 'd0;
    else for (int i = 0; i < M_DATA_COUNT; i++) begin
      if (arbiter_ready_i[i]) ready_ff[grant_i[i]] <= s_last_i[grant_i[i]] && m_ready_i[i];
    end 
  end

// ===================================================
// OUTPUT SIGNALS
// ===================================================

  assign m_id_o    = id_ff;
  assign m_data_o  = data_ff;
  assign m_valid_o = valid_ff;
  assign m_last_o  = last_ff;  
  assign s_ready_o = ready_ff;

endmodule