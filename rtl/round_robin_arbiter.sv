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

  This module set correct id after receiving mask for next clk rising edge. 

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
  |      |                     |         |     0 1 1 0 1 |             |             |             |
  --------------------------------------------------------------------------------------------------
  |    3 |           1 1 1 1 1 |       0 |     0 0 0 0 0 |           2 |           0 |           2 |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     0 0 0 1 0 |             |             |             |
  |      |                     |         |     0 1 1 0 0 |             |             |             |
  --------------------------------------------------------------------------------------------------
  |    4 |           1 1 1 1 1 |       1 |     0 0 0 0 0 |           2 |           0 |           3 |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     1 0 0 0 1 |             |             |             |
  |      |                     |         |     0 0 0 1 0 |             |             |             |
  |      |                     |         |     0 1 1 0 0 |             |             |             |
  --------------------------------------------------------------------------------------------------
  |    5 |           1 1 0 1 1 |       0 |     0 0 0 0 0 |           3 |          0  |           3 |
  |      |                     |         |     0 0 0 0 0 |             |             |             |
  |      |                     |         |     1 0 0 0 1 |             |             |             |
  |      |                     |         |     0 0 0 1 0 |             |             |             |
  |      |                     |         |     0 1 0 0 0 |             |             |             |
  --------------------------------------------------------------------------------------------------
*/

`timescale 1ns / 1ps

module round_robin_arbiter #(
  parameter  S_DATA_COUNT = 2,
             M_DATA_COUNT = 3,
             T_ID___WIDTH = $clog2(S_DATA_COUNT)
) (
  input  logic                    clk_i,
  input  logic                    rst_in,
    
  input  logic [S_DATA_COUNT-1:0] requests_mask_i,
  output logic [T_ID___WIDTH-1:0] id_o,

  input  logic [S_DATA_COUNT-1:0] last_i
);

// ==================================================
//  FLAGS
// ==================================================

  logic is_empty;               // true if array is empty. nobody in queue.
  logic is_valid;               // true if somebody of the masters set valid.
  logic is_start;               // true if record in masks list is about to start (after state of empty queue the masters made requests).
  logic is_new_mask;            // true if came valid from new master.

  logic is_last;                // true if came last signal from current working master.
  logic is_almost_empty_mask;   // true if list mask is about to reset to zero (masters in list mask is over).
  logic is_almost_empty;        // true if this is last mask in list.
  logic is_end_of_master;

  logic is_jump_to_next_mask;   // true if mask in list is almost empty, but still there are masters in queue (in other masks of list).
  logic is_almost_end;          // true if came last signal from last master in line and nobody want to get up in queue.
  logic is_was_almost_end;      // true if list of masks was almost end on prev tact. Need for detecting if last master in queue stayed alone keep logic one valid.
                                // and not rewrite one-bit mask from one cell to another to economy on dynamic power loss.
  logic is_dfntl_end;           // true if all masters in queue worked out and nobody set up valid in logic one.

  logic is_time_to_write;       // true if a new valid came and it is not in the list.
  logic is_time_for_shifitng;   // true if mask in list is over and necessary to read next mask in list.
  logic is_time_to_update_mask; // true if master in mask of list is over and needed delete him from queue.

  assign         is_empty               = ~|masters_in_line;
  assign         is_valid               = |crnt_mask;
  assign         is_start               = is_empty && is_valid;
  assign         is_new_mask            = |new_mask;

  assign         is_last                = last_i[id_o];
  assign         is_almost_empty_mask   = is_end_of_master && ~|(list_of_mask[ptr_rd_list] ^ lead_master_of_used_mask);
  assign         is_almost_empty        = (ptr_rd_list == S_DATA_COUNT - 1) ? (ptr_wr_list == 'd0) : (ptr_rd_list == ptr_wr_list - 1'd1);
  assign         is_end_of_master       = is_last && crnt_mask[ptr_rd_mask];

  assign         is_jump_to_next_mask   = is_almost_empty_mask && (!is_almost_end || is_new_mask);
  assign         is_almost_end          = is_almost_empty_mask && is_almost_empty && !is_new_mask;

  always_ff @(posedge clk_i) begin
    if (!rst_in) is_was_almost_end      = '0;
    else         is_was_almost_end      = is_almost_end;
  end

  assign         is_dfntl_end           = !is_valid && is_was_almost_end && !crnt_mask[ptr_rd_mask];

  assign         is_time_to_write       = is_start || is_new_mask;
  assign         is_time_for_shifitng   = !is_almost_end && (is_jump_to_next_mask || is_dfntl_end);
  assign         is_time_to_update_mask = !is_almost_end && (is_jump_to_next_mask || is_end_of_master || is_dfntl_end);  

// ==================================================
//  MAIN RESIGTERS
// ==================================================
  
  logic [S_DATA_COUNT-1 : 0] crnt_mask;
  logic [S_DATA_COUNT-1 : 0] list_of_mask [S_DATA_COUNT-1:0];   
  logic [S_DATA_COUNT-1 : 0] used_mask;

  assign crnt_mask = requests_mask_i;

  always_ff @(posedge clk_i) begin
    if   (!rst_in)                list_of_mask              <= '{S_DATA_COUNT{'0}};
    else begin
      if (is_time_to_update_mask) list_of_mask[ptr_rd_list] <= updated_mask;                           
      if (is_time_to_write)       list_of_mask[ptr_wr_list] <= new_mask;
    end
  end
  
  assign used_mask = list_of_mask[ptr_rd_list];
  
// ==================================================
//  LOGIC OF DEFINITION MASK FOR WRITING IN LIST
// ==================================================

  logic [S_DATA_COUNT-1 : 0] masters_in_line; // is needed to detect masters in line (in list) 
  logic [S_DATA_COUNT-1 : 0] updated_mask;    // as soon as master made his job, necessary reset to zero his bit in mask and update this mask in list
  logic [S_DATA_COUNT-1 : 0] new_mask;        // new mask for writing in list
  
  always_comb begin
    masters_in_line = '0;
    for (int i = 0; i < S_DATA_COUNT; i++) begin
      masters_in_line = masters_in_line | list_of_mask[i];
    end
  end
  
  assign updated_mask = used_mask ^ lead_master_of_used_mask;
  assign new_mask     = crnt_mask[ptr_rd_mask] ? (crnt_mask ^ masters_in_line) : (crnt_mask ^ masters_in_line ^ lead_master_of_used_mask);
  
// ==================================================
//  TO DEFINE BIT-MASK OF MASTER NUMBER
// ==================================================

  logic [S_DATA_COUNT-1 : 0] lead_master_of_used_mask;

  assign lead_master_of_used_mask = (1 << used_mask_low_bit) & {$size(used_mask){|used_mask}};

// ==================================================
//  TO DETECT NUMBER OF PRIORITY MASTER IN SOME MASK     
// ==================================================
  
  logic [T_ID___WIDTH-1 : 0] used_mask_low_bit;
  logic [T_ID___WIDTH-1 : 0] crnt_mask_low_bit;

// Mainly used to switch to next master inside used_mask, cell of array
  always_comb begin
    used_mask_low_bit = '0;
    for (int i = $low(used_mask); i <= $high(used_mask); i++) begin
      if (used_mask[i]) begin
        used_mask_low_bit = i;  
        break;
      end
    end
  end   

// Mainly used if array is empty or are being writing new cell 
  always_comb begin
    crnt_mask_low_bit = '0;
    for (int i = $low(crnt_mask); i <= $high(crnt_mask); i++) begin
      if (crnt_mask[i]) begin
        crnt_mask_low_bit = i; 
        break;
      end
    end
  end   

// ==================================================
//  POINTERS FOR ARRAY OF MASKS 
// ==================================================

  logic [T_ID___WIDTH-1 : 0] ptr_wr_list; // ptr_wr_list is indicating on row of requests array that will be overwritten
  logic [T_ID___WIDTH-1 : 0] ptr_rd_list; // ptr_rd_list is indicating on row of requests array that is being read
  logic [T_ID___WIDTH-1 : 0] ptr_rd_mask; // ptr_rd_mask is indicating on column (shifting inside the mask, indicating by prt_rd_list)
                                          // of requests array that is being read.
                                          // In fact ptr_rd_mask is used in couple with ptr_rd_list thereby choose necessary master.
 
  always_ff @(posedge clk_i) begin
    if      (!rst_in)                                                   ptr_rd_list <= 'd0;
    else if (is_time_for_shifitng) if (ptr_rd_list < S_DATA_COUNT - 1)  ptr_rd_list <= ptr_rd_list + 'd1;
                                   else                                 ptr_rd_list <= 'd0;
  end

  always_ff @(posedge clk_i) begin
    if      (!rst_in)                                              ptr_wr_list <= 'd0;
    else if (is_time_to_write) if (ptr_wr_list < S_DATA_COUNT - 1) ptr_wr_list <= ptr_wr_list + 'd1;
                               else                                ptr_wr_list <= 'd0;
  end

  always_comb begin
    if (!(is_start || is_empty)) ptr_rd_mask = used_mask_low_bit;
    else                         ptr_rd_mask = crnt_mask_low_bit;            
  end


// ==================================================
//  OUTPUT SIGNAL
// ==================================================

  assign id_o = ptr_rd_mask;
  
endmodule