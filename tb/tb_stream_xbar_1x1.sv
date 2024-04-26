`timescale 1ns / 1ps

module tb_stream_xbar_1x1;

// ==========================
//  INIT DUT
//===========================

  localparam T_DATA_WIDTH = 8;
  localparam S_DATA_COUNT = 1;
  localparam M_DATA_COUNT = 1;
  localparam T_ID___WIDTH = 1;
  localparam T_DEST_WIDTH = 1;

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

// ==========================
//  LOCAL STRUCTS AND PARAMS
//===========================

  localparam CLK_PERIOD         =      2;
  localparam TIMEOUT_CYCLES     = 100000;

  int errors_cnt = 0;

// ==========================
//  EXECUTION
//===========================

  initial begin
    $display("| ===================== |");
    $display("| STREAM X-BAR 1x1 TEST |");
    $display("| ===================== |");
    $display("\n");

    reset_system();
    
    @(posedge clk);
    set_data(1);
    s_dest[0] <= 0;

    skip_time();
    
    s_valid <= 1;

    set_data();

    m_ready <= 1; 

    set_data();
    s_last <= 1;
    
    s_valid <= 0;
    set_data();
    set_data(1);

  // ----------- FINISH ----------
    if (errors_cnt) $display("\n FAILED test with %d errors!!!", errors_cnt); 
    else            $display("\n The test is over without erros!!!");
    $finish;
  end

  property sReadyCorrect;
    @(posedge clk) m_ready && m_valid |-> s_ready;
  endproperty

  sReadyStable : assert property (sReadyCorrect) 
    $display("Time: %t | GOOD!!! m_ready = %d, m_valid = %d", $time(), m_ready, m_valid);
  else begin
    $display("Time: %t | ERROR!!! s_ready is not logic one", $time());
    $display("Time: %t | m_ready = %d, m_valid = %d", $time(), m_ready, m_valid);
    errors_cnt++;
  end

// ==========================
//  TASKS AND OTHER FOR JOB
//===========================

  initial begin
    clk <= 0;
    forever #(CLK_PERIOD / 2) clk <= ~clk;
  end

  task reset_system;
      rst_n     <= 0;
      s_data    <= '{S_DATA_COUNT{'0}};
      s_dest    <= '{S_DATA_COUNT{'0}};
      s_valid   <= '0;
      s_last    <= '0;
      s_ready   <= '0;  
      m_ready   <= '0;
      #CLK_PERIOD;
      rst_n <= 1;
  endtask

  task timeout;
    repeat(TIMEOUT_CYCLES) @(posedge clk);
    $stop();
  endtask

  task set_data(int times = 5);
    repeat (times) begin
      @(posedge clk);
      for (int i = 0; i < S_DATA_COUNT; i++) begin
        s_data[i] <= $urandom();
      end
    end
  endtask

  task skip_time(int times = 5);
    repeat(times) @(posedge clk);
  endtask

endmodule

