`timescale 1ns / 1ps

module tb_stream_xbar;

// ==========================
//  INIT DUT
//===========================

  localparam T_DATA_WIDTH = 8;
  localparam S_DATA_COUNT = 2;
  localparam M_DATA_COUNT = 3;
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

  // function void init_input_arrays(input int S_DATA_COUNT);
  //   for (int i = 0; i < S_DATA_COUNT; i++) begin
  //     s_data[i] <= $urandom();
  //     s_dest[i] <= $urandom();
  //   end
  // endfunction   

// ==========================
//  LOCAL STRUCTS AND PARAMS
//===========================

  localparam CLK_PERIOD         =      2;
  // localparam AMOUNT_TEST_VALUES =     10;
  localparam TIMEOUT_CYCLES     = 100000;

  // typedef struct {
  //     rand int          delay;
  //     rand logic [31:0] data;
  //     rand logic        id;
  //     rand logic        last;
  //     rand logic        source;
  //     rand logic        dest;
  // } packet;

  // mailbox#(packet) gen2drv = new();
  // mailbox#(packet) in_mbx  = new();
  // mailbox#(packet) out_mbx = new();

// ==========================
//  EXECUTION
//===========================

  initial begin
    reset_system();
    s_data[0] <= $urandom();
    s_data[1] <= $urandom();

    s_dest[0] <= 2;
    s_dest[1] <= 2;

    s_valid[0] <= 1;
    s_valid[1] <= 1;

    repeat(5) @(posedge clk); 

    @(posedge clk);
    m_ready <= 3'b100;

    for (int i = 0; i < 5; i++) begin
      @(posedge clk);
      s_data[0] <= $urandom();
      s_data[1] <= $urandom();
    end

    s_last[DUT.grant[2]] <= 1; // Last is set by leading master

    wait(m_ready[2]);
    @(posedge clk);

    repeat(5) @(posedge clk); 
    for (int i = 0; i < 5; i++) begin
      @(posedge clk);
      s_data[0] <= $urandom();
      s_data[1] <= $urandom();
    end

    s_last[DUT.grant[2]] <= 1;

  end


//   // Master
//   task gen_master(
//     int size_min   = 1,
//     int size_max   = 10,
//     int delay_min  = 0,
//     int delay_max  = 10,
//     int dest       = M_DATA_COUNT,
//     int source     = S_DATA_COUNT
// );
//     packet p;
//     int size;
//     void'(std::randomize(size) with {size inside {[size_min:size_max]};});
//     for(int i = 0; i < size; i = i + 1) begin
//         if( !std::randomize(p) with {
//             p.delay inside {[delay_min:delay_max]};
//             p.last == (i == size - 1);
            
//         } ) begin
//             $error("Can't randomize packet!");
//             $finish();
//         end
//         gen2drv.put(p);
//     end
//   endtask
  

//   task do_master_gen(
//     int pkt_amount = 100,
//     int size_min   = 1,
//     int size_max   = 10,
//     int delay_min  = 0,
//     int delay_max  = 10,
//     int dest   = M_DATA_COUNT,
//     int source = S_DATA_COUNT
//   );
//     repeat(pkt_amount) begin
//         gen_master(size_min, size_max, delay_min, delay_max, dest, source);
//     end
//   endtask

//   task reset_master();
//     wait(!rst_n);
//     s_valid <= 0;
//     s_data  <= 0;
//     s_id    <= 0;
//     wait(!rst_n);
//   endtask

//   task drive_master(packet p);
//     repeat(p.delay) @(posedge clk);
//     s_tvalid <= 1;
//     s_tdata  <= p.tdata;
//     s_tid    <= p.tdata;
//     s_tlast  <= p.tlast;
//     do begin
//         @(posedge clk);
//     end
//     while(~s_tready);
//     s_tvalid <= 0;
//     s_tlast  <= 0;
//   endtask

//     task do_master_drive();
//         packet p;
//         reset_master();
//         @(posedge clk);
//         forever begin
//             gen2drv.get(p);
//             drive_master(p);
//         end
//     endtask

//     task monitor_master();
//         packet p;
//         @(posedge clk);
//         if( s_tvalid & s_tready ) begin
//             p.tdata  = s_tdata;
//             p.tid    = s_tid;
//             p.tlast  = s_tlast;
//             in_mbx.put(p);
//         end
//     endtask

//     task do_master_monitor();
//         wait(aresetn);
//         forever begin
//             monitor_master();
//         end
//     endtask

//     // Master
//     task master(        
//         int gen_pkt_amount = 100,
//         int gen_size_min   = 1,
//         int gen_size_max   = 10,
//         int gen_delay_min  = 0,
//         int gen_delay_max  = 10,
//         int gen_dest       = 0 
//     );
//         fork
//             do_master_gen(gen_pkt_amount, gen_size_min, gen_size_max, gen_delay_min, gen_delay_max, gen_dest, gen_source);
//             do_master_drive();
//             do_master_monitor();
//         join
//     endtask

//     task test(
//         int gen_pkt_amount     = 100,   // количество пакетов 
//         int gen_size_min       = 1,     // мин. размер пакета
//         int gen_size_max       = 10,    // макс. размер пакета
//         int gen_delay_min      = 0,     // мин. задержка между транзакциями
//         int gen_delay_max      = 10,    // макс. задержка между транзакциями
//         int gen_dest           = M_DATA_COUNT,
//         int gen_source         = S_DATA_COUNT,
//         int slave_delay_min    = 0,     // минимальная задержка для slave
//         int slave_delay_max    = 10,    // максимальная задержка для slav
//         int timeout_cycles     = 100000 // таймаут теста
//     );
//         fork
//             master       (gen_pkt_amount, gen_size_min, gen_size_max, gen_delay_min, gen_delay_max);
//             slave        (slave_delay_min, slave_delay_max);
//             error_checker(gen_pkt_amount);
//             timeout      (timeout_cycles);
//         join
//     endtask















  // initial begin
  //   reset_system();
  //   fork
  //     initIn();
  //     catchOut();
  //     checkData();
  //   join
  // end
  
// ==========================
//  TASKS AND OTHER FOR JOB
//===========================

  initial begin
    clk <= 0;
    forever #(CLK_PERIOD / 2) clk <= ~clk;
  end

  task reset_system;
    begin
      rst_n     <= 0;
      s_data    <= '{S_DATA_COUNT{'0}};
      s_dest    <= '{S_DATA_COUNT{'0}};
      s_valid   <= '0;
      s_last    <= '0;
      s_ready   <= '0;  
      m_ready   <= '0;
      #CLK_PERIOD;
      rst_n <= 1;
    end
  endtask

  task timeout;
    repeat(TIMEOUT_CYCLES) @(posedge clk);
    $stop();
  endtask

//  task initIn;
//    begin
//      packet p;
//      @(negedge rst);
//      repeat (2) @(posedge clk);
//      for (int i = 0; i < AMOUNT_TEST_VALUES; i++) begin
//        @(posedge clk);
//        data_i  <= $urandom_range(0, 10);
//        valid_i <= $urandom_range(0,  1);
//        @(negedge clk);
//        p.data  <= data_i;
//        p.valid <= valid_i;
//        #1; $display("INPUT: time: %t, data: %d, valid: %d", $time(), p.data, p.valid);
//        in_mbx.put(p);
//      end
//    end
//  endtask

//  task catchOut;
//    begin
//      packet p;
//      @(negedge rst);
//      repeat (8) @(posedge clk);
//      $display("time: %t, POOPER", $time());
//      repeat (AMOUNT_TEST_VALUES) begin
//        @(negedge clk);
//        p.data  <= data_o;
//        p.valid <= valid_o;
//        #1; $display("OUTPUT: time: %t, data: %d, valid: %d", $time(), p.data, p.valid);
//        out_mbx.put(p);
//      end
//    end
//  endtask

//  task checkData;
//    begin
//      packet in_p, out_p;
//      forever begin
//        repeat (AMOUNT_TEST_VALUES) begin
//          in_mbx.get(in_p);
//          out_mbx.get(out_p);
//          #1;
//          $display("time: %t CHECK", $time());
//          $display("time: %t / data_input: %d, valid_input: %d, data_output: %d, valid_output: %d", $time(), in_p.data, in_p.valid, out_p.data, out_p.valid);
//          if (out_p.valid && out_p.data !== in_p.data ** 5) $error("Time: %t, Invalid data: Real: %d, Expected: %d", $time(), out_p.data, in_p.data ** 5);
//          if (out_p.valid !== in_p.valid)                   $error("Time: %t, Invalid valid: Real: %d, Expected: %d", $time(), out_p.valid, in_p.valid);
//        end
//      end
//    end
//  endtask


//  // ===== Slave ===== //
//  task reset_slave();
//    m_ready <= 0;
//  endtask

//  task slave (
//    int delay_min  = 0,
//    int delay_max  = 10
//  );
//    fork
//      do_slave_drive(delay_min, delay_max);
//      do_slave_monitor();
//    join
//  endtask

//  task do_slave_drive (
//    int delay_min  = 0,
//    int delay_max  = 10
//  );
//    forever begin
//      @(posedge clk);
//      fork
//        forever begin
//          drive_slave(delay_min, delay_max);
//        end
//      join_none
//      wait(!rst_n); 
//      disable fork;
//      reset_slave();
//      wait(rst_n);
//    end
//  endtask

//  task do_slave_monitor();
//    wait(aresetn);
//    forever begin
//      monitor_slave();
//    end
//  endtask

//  task drive_slave(
//    int delay_min  = 0,
//    int delay_max  = 10
//  );
//    int delay;
//    void'(std::randomize(delay) with {delay inside {[delay_min:delay_max]};});
//    repeat(delay) @(posedge clk);
//    m_ready <= 1;
//    @(posedge clk);
//    m_ready <= 0;
//  endtask

//  task monitor_slave();
//    packet p;
//    @(posedge clk);
//    if( m_tvalid & m_tready ) begin
//      p.tdata  = m_tdata;
//      p.tid    = m_tid;
//      p.tlast  = m_tlast;
//      out_mbx.put(p);
//    end
//  endtask 


endmodule