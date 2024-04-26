`timescale 1ns / 1ps

module tb_stream_xbar_3x4;

// ===============================================================================
//  INIT DUT
// ===============================================================================

  localparam T_DATA_WIDTH = 8;
  localparam S_DATA_COUNT = 3;
  localparam M_DATA_COUNT = 4;
  localparam T_ID___WIDTH = $clog2(S_DATA_COUNT);
  localparam T_DEST_WIDTH = $clog2(M_DATA_COUNT);

  logic                    clk;
  logic                    rst_n;
// multiple input streams
  logic [T_DATA_WIDTH-1:0] s_data [S_DATA_COUNT-1:0];
  logic [T_DEST_WIDTH-1:0] s_dest [S_DATA_COUNT-1:0];
  logic [S_DATA_COUNT-1:0] s_last;
  logic [S_DATA_COUNT-1:0] s_valid;
  logic [S_DATA_COUNT-1:0] s_ready;
// multiple output streams
  logic [T_DATA_WIDTH-1:0] m_data [M_DATA_COUNT-1:0];
  logic [T_ID___WIDTH-1:0] m_id   [M_DATA_COUNT-1:0];
  logic [M_DATA_COUNT-1:0] m_last;
  logic [M_DATA_COUNT-1:0] m_valid;
  logic [M_DATA_COUNT-1:0] m_ready;

  stream_xbar #(
    .T_DATA_WIDTH ( T_DATA_WIDTH ),
    .S_DATA_COUNT ( S_DATA_COUNT ),
    .M_DATA_COUNT ( M_DATA_COUNT )
  ) DUT (
    .clk       ( clk     ),
    .rst_n     ( rst_n   ),

    .s_data_i  ( s_data  ),
    .s_dest_i  ( s_dest  ),
    .s_last_i  ( s_last  ),
    .s_valid_i ( s_valid ),
    .s_ready_o ( s_ready ),

    .m_data_o  ( m_data  ),
    .m_id_o    ( m_id    ),
    .m_last_o  ( m_last  ),
    .m_valid_o ( m_valid ),
    .m_ready_i ( m_ready )
  );

// ===============================================================================
//  LOCAL STRUCTS AND PARAMS
// ===============================================================================

  localparam CLK_PERIOD     =      4;
  localparam TIMEOUT_CYCLES = 100000;

  logic [S_DATA_COUNT-1:0] expctd_ready;
  logic [M_DATA_COUNT-1:0] expctd_valid;
  logic [T_DATA_WIDTH-1:0] expctd_data [M_DATA_COUNT-1:0];
  logic [T_ID___WIDTH-1:0] expctd_id   [M_DATA_COUNT-1:0];
  logic [M_DATA_COUNT-1:0] expctd_last;

  logic [M_DATA_COUNT-1:0] ready;
  logic [S_DATA_COUNT-1:0] valid;
  logic [T_DEST_WIDTH-1:0] dest [S_DATA_COUNT-1:0];
  logic [S_DATA_COUNT-1:0] last;

  logic [S_DATA_COUNT-1:0] handshake;
  logic [S_DATA_COUNT-1:0] rewrite_mask; 

  int error_cnt = 0;

// ===============================================================================
//  EXECUTION
// ===============================================================================

  initial begin

    $display("| ===================== |");
    $display("| STREAM X-BAR 3x4 TEST |");
    $display("| ===================== |");
    $display("\n");

  // -------------
    reset_system();
  // -------------

  // ----------- SET №1 ------------
    $display("Time: %t | SET №1", $time());
    $display("Time: %t | Test of parallel work", $time());
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1111;
    valid = 3'b111;
    dest  = '{2, 1, 0};
    last  = 3'b000;
    set_input(ready, valid, dest, last); 

  // ----------- CHECK №1 ----------
    @(negedge clk); 
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = valid;
    expctd_data  = '{s_data[0], s_data[2], s_data[1], s_data[0]};
    expctd_id    = '{0, 2, 1, 0};
    expctd_last  = 4'b0000;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);
    $display("\n");

  // ----------- SET №2 ------------
    $display("Time: %t | SET №2", $time());
    $display("Time: %t | Test of work stoppage (2 and 0 master. 1 master has a last and valid signal)", $time());
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1111;
    valid = 3'b010;
    dest  = '{2, 1, 0};
    last  = 3'b111;
    set_input(ready, valid, dest, last);

  // ----------- CHECK №2 ----------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = valid;
    expctd_data  = '{s_data[0], s_data[2], s_data[1], s_data[0]};
    expctd_id    = '{0, 2, 1, 0};
    expctd_last  = 4'b1111;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);
    $display("\n");

  // ----------- SET №3 ------------
    $display("Time: %t | SET №3", $time());
    $display("Time: %t | Test of work stoppage after last signal (1-st master)", $time());
    $display("Time: %t | Test of m_ready", $time());
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1110;
    valid = 3'b101;
    dest  = '{2, 1, 0};
    last  = 3'b011;
    set_input(ready, valid, dest, last);

  // ----------- CHECK №3 ----------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = valid;
    expctd_data  = '{s_data[0], s_data[2], s_data[1], s_data[0]};
    expctd_id    = '{0, 2, 1, 0};
    expctd_last  = 4'b1011;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);
    $display("\n");

  // ----------- SET №4 ------------
    $display("Time: %t | SET №4", $time());
    $display("Time: %t | Test of work with same requests of 2 masters", $time());
    $display("Time: %t | Test of continuos single-in-queue work after last signal", $time());
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1111;
    valid = 3'b111;
    dest  = '{2, 2, 0};
    last  = 3'b001;
    set_input(ready, valid, dest, last);

  // ----------- CHECK №4 ----------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = 4'b0101;
    expctd_data  = '{s_data[0], s_data[2], s_data[0], s_data[0]};
    expctd_id    = '{0, 2, 0, 0};
    expctd_last  = 4'b1011;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);
    $display("\n");

  // ----------- SET №5 ------------
    $display("Time: %t | SET №5", $time());
    $display("Time: %t | Test of instant master standing in line after job", $time());
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1111;
    valid = 3'b111;
    dest  = '{2, 2, 0};
    last  = 3'b101;
    set_input(ready, valid, dest, last);

  // ----------- CHECK №5 ------------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = 4'b0101;
    expctd_data  = '{s_data[0], s_data[2], s_data[0], s_data[0]};
    expctd_id    = '{0, 2, 0, 0};
    expctd_last  = 4'b1111;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);
    $display("\n");

  // ----------- SET №6 ------------
    $display("Time: %t | SET №6", $time());
    $display("Time: %t | Test of master exchange", $time());
    $display("Time: %t | Test of all masters working on one slave", $time());
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1111;
    valid = 3'b011;
    dest  = '{2, 2, 2};
    last  = 3'b001;
    set_input(ready, valid, dest, last);

  // ----------- CHECK №6 ----------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = 4'b0100;
    expctd_data  = '{s_data[0], s_data[1], s_data[0], s_data[0]};
    expctd_id    = '{0, 1, 0, 0};
    expctd_last  = 4'b1011;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);
    $display("\n");

  // ----------- SET №7.1 ------------
    $display("Time: %t | SET №7", $time());
    $display("Time: %t | Test of work end", $time());
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1111;
    valid = 3'b011;
    dest  = '{2, 2, 2};
    last  = 3'b011;
    set_input(ready, valid, dest, last);

  // ----------- CHECK №7.1 ----------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = 4'b0100;
    expctd_data  = '{s_data[0], s_data[1], s_data[0], s_data[0]};
    expctd_id    = '{0, 1, 0, 0};
    expctd_last  = 4'b1111;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);

  // ----------- SET №7.2 ------------
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1111;
    valid = 3'b001;
    dest  = '{2, 2, 2};
    last  = 3'b001;
    set_input(ready, valid, dest, last);

  // ----------- CHECK №7.2 ----------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = 4'b0100;
    expctd_data  = '{s_data[0], s_data[0], s_data[0], s_data[0]};
    expctd_id    = '{0, 0, 0, 0};
    expctd_last  = 4'b1111;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);  

  // ----------- SET №7.3 ------------
    $display("Time: %t |", $time());
    @(posedge clk);
    handshake_mask();
    ready = 4'b1111;
    valid = 3'b000;
    dest  = '{2, 2, 2};
    last  = 3'b000;
    set_input(ready, valid, dest, last);

  // ----------- CHECK №7.3 ----------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = 4'b0000;
    expctd_data  = '{s_data[0], s_data[0], s_data[0], s_data[0]};
    expctd_id    = '{0, 0, 0, 0};
    expctd_last  = 4'b0000;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);  
    $display("\n");

  // -------------
    skip_time(2);
  // -------------   

  // ----------- SET №8 ------------
    $display("Time: %t | SET №8", $time());
    $display("Time: %t | Test of reset", $time());
    $display("Time: %t |", $time());
    reset_system();

  // ----------- CHECK №8 ----------
    @(negedge clk);
    handshake_mask();
    expctd_ready = handshake;
    expctd_valid = 4'b0000;
    expctd_data  = '{0, 0, 0, 0};
    expctd_id    = '{0, 0, 0, 0};
    expctd_last  = 4'b0000;
    #1;
    check_out(expctd_ready, expctd_valid, expctd_data, expctd_id, expctd_last);
    $display("\n");

  // -------------
    skip_time(1);
  // -------------    

  // ----------- FINISH ----------
    if (error_cnt) $display("\n FAILED test with %d errors!!!", error_cnt); 
    else           $display("\n The test is over without erros!!!");
    $finish;
  end

// ===============================================================================
//  TASKS AND OTHER FOR JOB
// ===============================================================================

  initial begin
    clk <= 0;
    forever #(CLK_PERIOD / 2) clk <= ~clk;
  end

  task reset_system();
    rst_n     <= 0;
    s_data    <= '{S_DATA_COUNT{'0}};
    s_dest    <= '{S_DATA_COUNT{'0}};
    s_valid   <= '0;
    s_last    <= '0;
    s_ready   <= '0;  
    m_ready   <= '0;
    @(posedge clk);
    rst_n     <= 1;
  endtask

  task timeout();
    repeat(TIMEOUT_CYCLES) @(posedge clk);
    $display("TIMEOUT!!!");
    $stop();
  endtask

  task skip_time (
    int times = 5
  );
    repeat(times) @(posedge clk);
  endtask

  task handshake_mask();
    for (int m_idx = 0; m_idx < S_DATA_COUNT; m_idx = m_idx + 1) begin
      handshake[m_idx] = m_valid[s_dest[m_idx]]  & m_ready[s_dest[m_idx]];
      // $display("Time: %t | rewrite[%d] = %d", $time(), m_idx, rewrite_mask[m_idx]); 
    end
  endtask

  task set_input (
    logic [M_DATA_COUNT-1:0] ready,
    logic [S_DATA_COUNT-1:0] valid,
    logic [T_DEST_WIDTH-1:0] dest [S_DATA_COUNT-1:0],
    logic [S_DATA_COUNT-1:0] last
  );
    for (int m_idx = 0; m_idx < S_DATA_COUNT; m_idx = m_idx + 1) begin
      rewrite_mask[m_idx] = !s_valid[m_idx] || handshake[m_idx];
      // $display("Time: %t | rewrite[%d] = %d", $time(), m_idx, rewrite_mask[m_idx]); 
    end

    set_data (       rewrite_mask);
    set_dest (dest , rewrite_mask); 
    set_valid(valid, rewrite_mask);
    set_last (last , rewrite_mask);
    m_ready <= ready;
  endtask

  task set_data (
    logic [S_DATA_COUNT-1:0] rewrite_mask
  );
  logic [T_DATA_WIDTH-1:0] tmp_data [S_DATA_COUNT-1:0];
    for (int i = 0; i < S_DATA_COUNT; i++) begin
      tmp_data[i] = $urandom(); 
      if (rewrite_mask[i]) s_data[i] <= tmp_data[i];
    end
  endtask

  task set_dest (
    logic [T_DEST_WIDTH-1:0] dest [S_DATA_COUNT-1:0],
    logic [S_DATA_COUNT-1:0] rewrite_mask
  );
    for (int i = 0; i < S_DATA_COUNT; i++) begin
      if (rewrite_mask[i]) s_dest[i] <= dest[i];
    end
  endtask

  task set_valid (
    logic [S_DATA_COUNT-1:0] valid,
    logic [S_DATA_COUNT-1:0] rewrite_mask
  );
    for (int i = 0; i < S_DATA_COUNT; i++) begin
      if (rewrite_mask[i]) s_valid[i] <= valid[i];
    end
  endtask

  task set_last (
    logic [S_DATA_COUNT-1:0] last,
    logic [S_DATA_COUNT-1:0] rewrite_mask
  );
    for (int i = 0; i < S_DATA_COUNT; i++) begin
      if (rewrite_mask[i]) s_last[i] <= last[i];
    end
  endtask

  task check_out (
    logic [S_DATA_COUNT-1:0] expctd_ready,
    logic [M_DATA_COUNT-1:0] expctd_valid,
    logic [T_DATA_WIDTH-1:0] expctd_data [M_DATA_COUNT-1:0],
    logic [T_ID___WIDTH-1:0] expctd_id   [M_DATA_COUNT-1:0],
    logic [M_DATA_COUNT-1:0] expctd_last
  );
  // ---------------------------------------------------------------------------------
    if (s_ready[0] !== expctd_ready[0]) begin 
      $display("Time: %t | Invalid READY[0]: Real: %b, Expected: %b", $time(), s_ready[0], expctd_ready[0]);
      error_cnt++; 
    end
    if (s_ready[1] !== expctd_ready[1]) begin
      $display("Time: %t | Invalid READY[1]: Real: %b, Expected: %b", $time(), s_ready[1], expctd_ready[1]);
      error_cnt++;
    end 
    if (s_ready[2] !== expctd_ready[2]) begin
      $display("Time: %t | Invalid READY[2]: Real: %b, Expected: %b", $time(), s_ready[2], expctd_ready[2]);
      error_cnt++;
    end
  // ---------------------------------------------------------------------------------
    if (m_valid[0] !== expctd_valid[0]) begin
      $display("Time: %t | Invalid VALID[0]: Real: %b, Expected: %b", $time(), m_valid[0], expctd_valid[0]);
      error_cnt++;
    end
    if (m_valid[1] !== expctd_valid[1]) begin
      $display("Time: %t | Invalid VALID[1]: Real: %b, Expected: %b", $time(), m_valid[1], expctd_valid[1]);
      error_cnt++;
    end 
    if (m_valid[2] !== expctd_valid[2]) begin
      $display("Time: %t | Invalid VALID[2]: Real: %b, Expected: %b", $time(), m_valid[2], expctd_valid[2]);
      error_cnt++;
    end 
    if (m_valid[3] !== expctd_valid[3]) begin
      $display("Time: %t | Invalid VALID[3]: Real: %b, Expected: %b", $time(), m_valid[3], expctd_valid[3]);
      error_cnt++;
    end 
  // ---------------------------------------------------------------------------------
    if (m_data[0] !== expctd_data[0]) begin
      $display("Time: %t | Invalid DATA[0]: Real: %h, Expected: %h", $time(), m_data[0], expctd_data[0]);
      error_cnt++;
    end
    if (m_data[1] !== expctd_data[1]) begin
      $display("Time: %t | Invalid DATA[1]: Real: %h, Expected: %h", $time(), m_data[1], expctd_data[1]);
      error_cnt++;
    end
    if (m_data[2] !== expctd_data[2]) begin
      $display("Time: %t | Invalid DATA[2]: Real: %h, Expected: %h", $time(), m_data[2], expctd_data[2]);
      error_cnt++;
    end
    if (m_data[3] !== expctd_data[3]) begin
      $display("Time: %t | Invalid DATA[3]: Real: %h, Expected: %h", $time(), m_data[3], expctd_data[3]);
      error_cnt++;
    end
  // ---------------------------------------------------------------------------------
    if (m_id[0] !== expctd_id[0]) begin
      $display("Time: %t | Invalid ID[0]: Real: %h, Expected: %h", $time(), m_id[0], expctd_id[0]);
      error_cnt++;
    end
    if (m_id[1] !== expctd_id[1]) begin
      $display("Time: %t | Invalid ID[1]: Real: %h, Expected: %h", $time(), m_id[1], expctd_id[1]);
      error_cnt++;
    end
    if (m_id[2] !== expctd_id[2]) begin
      $display("Time: %t | Invalid ID[2]: Real: %h, Expected: %h", $time(), m_id[2], expctd_id[2]);
      error_cnt++;
    end
    if (m_id[3] !== expctd_id[3]) begin
      $display("Time: %t | Invalid ID[3]: Real: %h, Expected: %h", $time(), m_id[3], expctd_id[3]);
      error_cnt++;
    end
  // ---------------------------------------------------------------------------------
    if (m_last[0] !== expctd_last[0]) begin
      $display("Time: %t | Invalid LAST[0]: Real: %b, Expected: %b", $time(), m_last[0], expctd_last[0]);
      error_cnt++;
    end
    if (m_last[1] !== expctd_last[1]) begin
      $display("Time: %t | Invalid LAST[1]: Real: %b, Expected: %b", $time(), m_last[1], expctd_last[1]);
      error_cnt++;
    end
    if (m_last[2] !== expctd_last[2]) begin
      $display("Time: %t | Invalid LAST[2]: Real: %b, Expected: %b", $time(), m_last[2], expctd_last[2]);
      error_cnt++;
    end
    if (m_last[3] !== expctd_last[3]) begin
      $display("Time: %t | Invalid LAST[3]: Real: %b, Expected: %b", $time(), m_last[3], expctd_last[3]);
      error_cnt++;
    end
  // ---------------------------------------------------------------------------------
  endtask

endmodule

// `timescale 1ns / 1ps

// module tb_stream_xbar;

// // ==========================
// //  INIT DUT
// //===========================

//   localparam T_DATA_WIDTH = 8;
//   localparam S_DATA_COUNT = 3;
//   localparam M_DATA_COUNT = 3;
//   localparam T_ID___WIDTH = $clog2(S_DATA_COUNT);
//   localparam T_DEST_WIDTH = $clog2(M_DATA_COUNT);

//   logic                    clk;
//   logic                    rst_n;
// // multiple input streams
//   logic [T_DATA_WIDTH-1:0] s_data [S_DATA_COUNT-1:0];
//   logic [T_DEST_WIDTH-1:0] s_dest [S_DATA_COUNT-1:0];
//   logic [S_DATA_COUNT-1:0] s_last;
//   logic [S_DATA_COUNT-1:0] s_valid;
//   logic [S_DATA_COUNT-1:0] s_ready;
// // multiple output streams
//   logic [T_DATA_WIDTH-1:0] m_data [M_DATA_COUNT-1:0];
//   logic [T_ID___WIDTH-1:0] m_id   [M_DATA_COUNT-1:0];
//   logic [M_DATA_COUNT-1:0] m_last;
//   logic [M_DATA_COUNT-1:0] m_valid;
//   logic [M_DATA_COUNT-1:0] m_ready;

//   stream_xbar #(
//     .T_DATA_WIDTH ( T_DATA_WIDTH ),
//     .S_DATA_COUNT ( S_DATA_COUNT ),
//     .M_DATA_COUNT ( M_DATA_COUNT )
//   ) DUT (
//     .clk       ( clk     ),
//     .rst_n     ( rst_n   ),

//     .s_data_i  ( s_data  ),
//     .s_dest_i  ( s_dest  ),
//     .s_last_i  ( s_last  ),
//     .s_valid_i ( s_valid ),
//     .s_ready_o ( s_ready ),

//     .m_data_o  ( m_data  ),
//     .m_id_o    ( m_id    ),
//     .m_last_o  ( m_last  ),
//     .m_valid_o ( m_valid ),
//     .m_ready_i ( m_ready )
//   );

// // ==========================
// //  LOCAL STRUCTS AND PARAMS
// //===========================

//   localparam CLK_PERIOD         =      2;
//   localparam TIMEOUT_CYCLES     = 100000;

// // ==========================
// //  EXECUTION
// //===========================

//   initial begin
//     reset_system();
    
//     @(posedge clk);
//     set_data(1);
//     s_dest[0] <= 2;
//     s_dest[1] <= 2;
//     s_dest[2] <= 0;

//     skip_time();
    
//     s_valid[0] <= 1;
//     s_valid[1] <= 1;
//     s_valid[2] <= 1;

//     set_data();

//     m_ready <= 3'b111;
//     set_data();
//     // s_last[DUT.grant[2]] <= 1; // Last is set by leading master
//     // s_last[DUT.grant[1]] <= 1; 
//     // s_last[DUT.grant[0]] <= 1;
//     s_last <= '1;
//     set_data();
//     s_dest[2] <= 2;
//     set_data(1);

//   end

// // ==========================
// //  TASKS AND OTHER FOR JOB
// //===========================

//   initial begin
//     clk <= 0;
//     forever #(CLK_PERIOD / 2) clk <= ~clk;
//   end

//   task reset_system;
//       rst_n     <= 0;
//       s_data    <= '{S_DATA_COUNT{'0}};
//       s_dest    <= '{S_DATA_COUNT{'0}};
//       s_valid   <= '0;
//       s_last    <= '0;
//       s_ready   <= '0;  
//       m_ready   <= '0;
//       #CLK_PERIOD;
//       rst_n <= 1;
//   endtask

//   task timeout;
//     repeat(TIMEOUT_CYCLES) @(posedge clk);
//     $stop();
//   endtask

//   task set_data(int times = 5);
//     repeat (times) begin
//       @(posedge clk);
//       for (int i = 0; i < S_DATA_COUNT; i++) begin
//         s_data[i] <= $urandom();
//       end
//     end
//   endtask

//   task skip_time(int times = 5);
//     repeat(times) @(posedge clk);
//   endtask

// endmodule