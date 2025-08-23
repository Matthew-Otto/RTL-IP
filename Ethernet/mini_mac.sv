// Will take a stream of bytes from ethernet interface, remove headers and check crc
// buffers entire frame while receiving. if crc check fails, frame will be discarded
module mini_mac #(
  parameter DEST_MAC = 48'hFFFFFF_FFFFFF,
  parameter SRC_MAC = 48'h0007ed123456,
  parameter ETH_TYPE = 16'h88B5
) (
  input  logic       clk,  // 125MHz clock
  input  logic       reset,
  output logic       pcs_locked,

  // RX payload interface
  input  logic       ready_out,
  output logic       valid_out,
  output logic [7:0] data_out,
  output logic       eof_out,

  // TX payload interface
  output logic       ready_in,
  input  logic       valid_in,
  input  logic [7:0] data_in,
  input  logic       eof_in,

  // SERDES interface
  input  logic       rx_clk,
  input  logic [9:0] rx_data,
  output logic       rx_bitslip,
  output logic [9:0] tx_data
);

  logic       pcs_valid_out;
  logic [7:0] pcs_data_out;
  logic       pcs_eof_out;

  logic       pcs_valid_in;
  logic [7:0] pcs_data_in;
  logic       pcs_eof_in;

  sgmii_pcs sgmii_pcs_i (
    .clk,
    .reset,
    .pcs_locked,
    .valid_in(pcs_valid_in),
    .data_in(pcs_data_in),
    .eof_in(pcs_eof_in),
    .valid_out(pcs_valid_out),
    .data_out(pcs_data_out),
    .eof_out(pcs_eof_out),
    .rx_clk,
    .rx_data,
    .rx_bitslip,
    .tx_data
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////////////
  //// RX Channel //////////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////////
  
  logic       crc_pass;
  logic       crc_fail;
  logic       buffer_wr_en;
  logic       eof_wr;
  logic [7:0] rx_shift_reg [4:0];
  logic [4:0] rx_cnt, next_rx_cnt;

  always_ff @(posedge clk) begin
    rx_shift_reg[4] <= pcs_data_out;
    for (int i = 0; i < 4; i++)
      rx_shift_reg[i] <= rx_shift_reg[i+1];
  end
    
  enum {
    RX_IDLE,
    RX_HEADER,
    RX_PAYLOAD
  } rx_state, next_rx_state;
  
  always_ff @(posedge clk) begin
    if (reset || ~pcs_locked) rx_state <= RX_IDLE;
    else                      rx_state <= next_rx_state;

    rx_cnt <= next_rx_cnt;
  end

  always_comb begin
    next_rx_state = rx_state;
    next_rx_cnt = rx_cnt;
    buffer_wr_en = 0;
    eof_wr = 0;

    case (rx_state)
      RX_IDLE : begin
        next_rx_cnt = 17;
        if (pcs_valid_out)
          next_rx_state = RX_HEADER;
      end

      RX_HEADER : begin
        if (pcs_valid_out) begin
          if (~|rx_cnt)
            next_rx_state = RX_PAYLOAD;
          else
            next_rx_cnt = rx_cnt - 1;
        end
      end

      RX_PAYLOAD : begin
        buffer_wr_en = pcs_valid_out;

        if (pcs_eof_out) begin
          eof_wr = 1;
          next_rx_state = RX_IDLE;
        end
      end
    endcase
  end

  // Frame buffer
  spec_fifo #(
    .WIDTH(9),
    .DEPTH(2048)
  ) spec_fifo_i (
    .clk,
    .reset,
    .commit(crc_pass),
    .revert(crc_fail || ~pcs_locked),
    .ready_in(),
    .valid_in(buffer_wr_en),
    .data_in({eof_wr,rx_shift_reg[0]}),
    .ready_out(ready_out),
    .valid_out(valid_out),
    .data_out({eof_out,data_out})
  );

  // CRC check
  crc32_8b crc32_8b_rx (
    .clk,
    .reset,
    .data_valid(pcs_valid_out),
    .data_in(pcs_data_out),
    .eof(pcs_eof_out),
    .fcs_good(crc_pass),
    .fcs_bad(crc_fail),
    .crc_out()
  );



  //////////////////////////////////////////////////////////////////////////////////////////////////////////
  //// TX Channel //////////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////////

  logic [4:0]  tx_cnt, next_tx_cnt;
  
  logic        tx_buffer_ready;
  logic [7:0]  tx_buffer_data;
  logic        tx_buffer_eof;

  logic [4:0]  packet_cnt;
  logic        process_packet;

  logic        tx_latch_crc;
  logic        tx_crc_en;
  logic [31:0] tx_crc;
  logic [23:0] tx_crc_buffer;

  logic [5:0]  tx_pad_len, next_tx_pad_len;

  enum {
    TX_IDLE,
    TX_DEST_MAC,
    TX_SRC_MAC,
    TX_ETH_TYPE,
    TX_PAYLOAD,
    TX_PAYLOAD_PAD,
    TX_FCS,
    TX_IPG
  } tx_state, next_tx_state;

  always_ff @(posedge clk) begin
    if (reset) tx_state <= TX_IDLE;
    else       tx_state <= next_tx_state;

    tx_cnt <= next_tx_cnt;
    tx_pad_len <= next_tx_pad_len;
  end

  always_comb begin
    next_tx_state = tx_state;
    next_tx_cnt = tx_cnt;
    pcs_valid_in = 0;
    pcs_data_in = 0;
    pcs_eof_in = 0;
    tx_buffer_ready = 0;
    tx_latch_crc = 0;
    tx_crc_en = 0;
    process_packet = 0;
    next_tx_pad_len = tx_pad_len;

    case (tx_state)
      TX_IDLE : begin
        if (|packet_cnt) begin
          process_packet = 1;
          next_tx_cnt = 5;
          next_tx_state = TX_DEST_MAC;
        end
      end

      TX_DEST_MAC : begin
        tx_crc_en = 1;
        pcs_valid_in = 1;
        pcs_data_in = DEST_MAC[tx_cnt*8+:8];

        if (tx_cnt == 0) begin
          next_tx_cnt = 5;
          next_tx_state = TX_SRC_MAC;
        end else begin
          next_tx_cnt = tx_cnt - 1;
        end
      end

      TX_SRC_MAC : begin
        tx_crc_en = 1;
        pcs_valid_in = 1;
        pcs_data_in = SRC_MAC[tx_cnt*8+:8];

        if (tx_cnt == 0) begin
          next_tx_cnt = 1;
          next_tx_state = TX_ETH_TYPE;
        end else begin
          next_tx_cnt = tx_cnt - 1;
        end
      end

      TX_ETH_TYPE : begin
        tx_crc_en = 1;
        pcs_valid_in = 1;
        pcs_data_in = ETH_TYPE[tx_cnt*8+:8];

        if (tx_cnt == 0) begin
          next_tx_pad_len = 6'd45;
          next_tx_state = TX_PAYLOAD;
        end else begin
          next_tx_cnt = tx_cnt - 1;
        end
      end

      TX_PAYLOAD : begin
        tx_crc_en = 1;
        pcs_valid_in = 1;
        tx_buffer_ready = 1;
        pcs_data_in = tx_buffer_data;
        
        if (tx_pad_len != 0)
          next_tx_pad_len = tx_pad_len - 1;

        if (tx_buffer_eof) begin
          next_tx_cnt = 3;
          next_tx_state = (tx_pad_len == 0) ? TX_FCS : TX_PAYLOAD_PAD;
        end
      end

      TX_PAYLOAD_PAD : begin
        tx_crc_en = 1;
        pcs_valid_in = 1;
        pcs_data_in = 0;

        if (tx_pad_len == 0) begin
          next_tx_state = TX_FCS;
        end else begin
          next_tx_pad_len = tx_pad_len - 1;
        end
      end

      TX_FCS : begin
        pcs_valid_in = 1;
        if (tx_cnt == 3) begin
          pcs_data_in = tx_crc[7:0];
          tx_latch_crc = 1;
        end else begin
          pcs_data_in = tx_crc_buffer[(2-tx_cnt)*8+:8];
        end

        if (tx_cnt == 0) begin
          pcs_eof_in = 1;
          next_tx_cnt = 11;
          next_tx_state = TX_IPG;
        end else begin
          next_tx_cnt = tx_cnt - 1;
        end
      end

      TX_IPG : begin
        if (tx_cnt == 0) begin
          next_tx_state = TX_IDLE;
        end else begin
          next_tx_cnt = tx_cnt - 1;
        end
      end
    endcase
  end


  // Buffer entire packets coming into the MAC
  fifo #(
    .WIDTH(9),
    .DEPTH(2048)
  ) tx_buffer (
    .clk,
    .reset,
    .ready_in(ready_in),
    .valid_in(valid_in),
    .data_in({eof_in,data_in}),
    .ready_out(tx_buffer_ready),
    .valid_out(),
    .data_out({tx_buffer_eof,tx_buffer_data}),
    .almost_full(),
    .almost_empty()
  );

  // count number of frames currently in buffer
  always_ff @(posedge clk) begin
    if (reset)
      packet_cnt <= 0;
    else
      case ({(ready_in && valid_in && eof_in),process_packet})
        2'b10 : packet_cnt <= packet_cnt + 1;
        2'b01 : packet_cnt <= packet_cnt - 1;
        default;
      endcase
  end

  crc32_8b crc32_8b_tx (
    .clk,
    .reset,
    .data_valid(tx_crc_en),
    .data_in(pcs_data_in),
    .eof(tx_latch_crc),
    .crc_out(tx_crc),
    .fcs_good(),
    .fcs_bad()
  );

  always_ff @(posedge clk) begin
    if (tx_latch_crc)
      tx_crc_buffer <= tx_crc[31:8];
  end

endmodule : mini_mac
