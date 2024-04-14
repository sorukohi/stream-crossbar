/*
  DESCRIPTION
*/
/*
  Coming requests_mask of masters for given slave.
  Who will be communicate?

  Round-Robin politics:
  - master is being changing if transaction is completed: coming last signal from working master.
  - masters will "get up in queue".
  - if several masters give request at one point in time
    then will be choose higher priority: from low requests_mask bit to high.
    And other get up in queue following this rule. 

  This module set correct id and ready signal to output on next clk rising edge after receiving mask 

  Algorithm of operation:
    Using for example the 5 masters: cell of masks list = [4:0]
    There is list of masks. Size of mask is S_DATA_COUNT - amount of masters.
    Amount of cells in list will be also 5 because even if all masters set request at different times
    and thus will keep valid signal in logic one will be busy only as many cells as there are masters in total.

  Example of important:
  --------------------------------------------------------------------------------------------------
  | TACT | input requests_mask | is_last | list of masks | ptr_rd_mask | ptr_rd_list | ptr_wr_list | 
  --------------------------------------------------------------------------------------------------
  |    1 |           0 1 1 0 1 |       0 |     0 0 0 0 0 |           0 |           0 |           0 |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  --------------------------------------------------------------------------------------------------
  |    2 |           0 1 1 1 1 |       1 |     0 0 0 0 0 |           0 |           0 |           1 |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 1 1 0 0 |             |             |             |
  --------------------------------------------------------------------------------------------------
  |    3 |           1 1 1 1 1 |       0 |     0 0 0 0 0 |           2 |           0 |           2 |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 1 0 |             |             |             |
  |      |                     |         |     0 1 0 0 0 |             |             |             |
  --------------------------------------------------------------------------------------------------
  |    4 |           1 1 1 1 1 |       1 |     0 0 0 0 0 |           2 |           0 |           3 |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     1 0 0 0 1 |             |             |             |
  |      |                     |         |     0 0 0 1 0 |             |             |             |
  |      |                     |         |     0 1 0 0 0 |             |             |             |
  --------------------------------------------------------------------------------------------------
  |    5 |           1 1 0 1 1 |       0 |     0 0 0 0 0 |           3 |          0  |           3 |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     1 0 0 0 1 |             |             |             |
  |      |                     |         |     0 0 0 1 0 |             |             |             |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  --------------------------------------------------------------------------------------------------
  
  NOTES: 
  - When is being recorded in list new mask, position in list of next master reset to zero.
    It is necessary for detecting is_empty_mask flag to shift ptr_rd_list on time.  
*/

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

// ==============================================================================
//  FLAGS
// ==============================================================================

  logic is_empty;      // array is empty. nobody in queue.
  logic is_new_mask;   // coming new valid from some master.
  logic is_empty_mask; // current cell of array (used_mask) is empty. shift ptr_rd_list is needed.
  logic is_last;       // coming last signal from current working master.
  logic is_was_last    // was last in prev tact
  
  assign is_empty      = (ptr_wr_list == ptr_rd_list);
  assign is_new_mask   = (crnt_mask != last_mask);
  assign is_empty_mask = ~|used_mask && !is_empty;
  assign is_last       = last_i[id_o];

  always_ff @(posedge clk_i) begin
    if (!rst_in) is_was_last <= '0;
    else         is_was_last <= is_last;
  end
  
// ==============================================================================
//  MAIN RESIGTERS
// ==============================================================================
  
  logic [S_DATA_COUNT-1 : 0] crnt_mask;
  logic [S_DATA_COUNT-1 : 0] last_mask;
  logic [S_DATA_COUNT-1 : 0] list_of_mask [S_DATA_COUNT-1:0];   
  logic [S_DATA_COUNT-1 : 0] used_mask;

  assign crnt_mask = requests_mask_i;

  always_ff @(posedge clk_i) begin
    if (!rst_in) last_mask <= '0; 
    else         last_mask <= crnt_mask;
  end

  always_ff @(posedge clk_i) begin
    if   (!rst_in)                                list_of_mask              <= '{S_DATA_COUNT{'0}};
    else begin
      if (is_was_last && !is_empty_mask && !is_empty) list_of_mask[ptr_rd_list]     <= updated_mask;
      else                                        list_of_mask[ptr_rd_list + 1] <= next_mask;
      if (is_new_mask)                            list_of_mask[ptr_wr_list]     <= new_mask;
    end
  end
  
  assign used_mask = list_of_mask[ptr_rd_list];
  
// ==============================================================================
//  LOGIC OF DEFINITION MASK FOR WRITING IN LIST
// ==============================================================================

  logic [S_DATA_COUNT-1 : 0] masters_in_line;
  logic [S_DATA_COUNT-1 : 0] updated_mask;
  logic [S_DATA_COUNT-1 : 0] next_mask;
  logic [S_DATA_COUNT-1 : 0] new_mask;
  
  always_comb begin
    for (int i = 0; i < S_DATA_COUNT; i++) begin
      masters_in_line[i] = |list_of_mask[i];
    end
  end

  // new mask for writing in list
  assign updated_mask = lead_master_of_used_mask ^ crnt_mask ^ masters_in_line;
  assign next_mask    = lead_master_of_next_mask ^ crnt_mask ^ masters_in_line;
  assign new_mask     = lead_master_of_new_mask  ^ crnt_mask ^ masters_in_line;
  
// ==============================================================================
//  TO DEFINE BIT-MASK OF MASTER NUMBER
// ==============================================================================

  logic [S_DATA_COUNT-1 : 0] lead_master_of_used_mask;
  logic [S_DATA_COUNT-1 : 0] lead_master_of_next_mask;
  logic [S_DATA_COUNT-1 : 0] lead_master_of_new_mask;

  assign lead_master_of_used_mask = (1 << used_mask_low_bit);
  assign lead_master_of_next_mask = (1 << next_used_mask_low_bit);
  assign lead_master_of_new_mask  = (1 << crnt_mask_low_bit);

// ==============================================================================
//  TO DETECT NUMBER OF PRIORITY MASTER IN SOME MASK     
// ==============================================================================
  
  logic [T_ID___WIDTH-1 : 0] used_mask_low_bit;
  logic [T_ID___WIDTH-1 : 0] next_used_mask_low_bit;
  logic [T_ID___WIDTH-1 : 0] crnt_mask_low_bit;

// Mainly used to switch to next master inside used_mask, cell of array
  always_comb begin
    for (int i = $low(used_mask); i <= $high(used_mask); i++) begin
      if (used_mask[i]) begin
        used_mask_low_bit = i;  
        break;
      end
    end
  end   

// Mainly used if used_mask in array is empty is empty and necessary switch to next cell 
  always_comb begin
    for (int i = $low(list_of_mask, 1); i <= $high(list_of_mask, 1); i++) begin
      if (list_of_mask[ptr_rd_list + 1]) begin
        next_used_mask_low_bit = i;  
        break;
      end
    end
  end

// Mainly used if array is empty or are being writing new cell 
  always_comb begin
    for (int i = $low(crnt_mask); i <= $high(crnt_mask); i++) begin
      if (crnt_mask[i]) begin
        crnt_mask_low_bit = i; 
        break;
      end
    end
  end   

// ==============================================================================
//  MASKS ARRAY POINTERS
// ==============================================================================

  logic [T_ID___WIDTH-1 : 0] ptr_wr_list; // ptr_wr_list is indicating on row of requests array that will be overwritten
  logic [T_ID___WIDTH-1 : 0] ptr_rd_list; // ptr_rd_list is indicating on row of requests array that is being read
  logic [T_ID___WIDTH-1 : 0] ptr_rd_mask; // ptr_rd_mask is indicating on column (shifting inside the mask, indicating by prt_rd_list)
                                          // of requests array that is being read.
                                          // In fact ptr_rd_mask is used in couple with ptr_rd_list thereby choose necessary master.
 
  always_ff @(posedge clk_i) begin
    if      (!rst_in)                                                           ptr_rd_list <= 'd0;
    else if (is_empty_mask && is_was_last) if (ptr_rd_list < S_DATA_COUNT - 1)  ptr_rd_list <= ptr_rd_list + 'd1;
                                           else                                 ptr_rd_list <= 'd0;
  end

  always_ff @(posedge clk_i) begin
    if      (!rst_in)                                         ptr_wr_list <= 'd0;
    else if (is_new_mask) if (ptr_wr_list < S_DATA_COUNT - 1) ptr_wr_list <= ptr_wr_list + 'd1;
                          else                                ptr_wr_list <= 'd0;
  end
 
  always_ff @(posedge clk_i) begin
    if      (!rst_in)                         ptr_rd_mask <= 'd0;
    else if (is_was_last) if (!is_empty_mask) ptr_rd_mask <= used_mask_low_bit;
                          else                ptr_rd_mask <= next_used_mask_low_bit;
    else if (is_empty)                        ptr_rd_mask <= crnt_mask_low_bit;
  end

// ==============================================================================
//  OUTPUT SIGNALS
// ==============================================================================

  assign ready_o = !is_empty;
  assign id_o    = ptr_rd_mask;
  
endmodule