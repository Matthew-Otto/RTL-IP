// sgmii PCS
// Takes raw ethernet frame bytes from MAC and sends them to PHY over SGMII link

// Assumes hard logic SERDES block with bitslip support
// Assumes Marvel 88E1111 (or compatible) PHY
// Does not support autonegotiation. 
// Requires configuring PHY over MDIO (to disable autonegotiation)


module sgmii_pcs (
  input  logic       clk, // 125MHz phase-aligned clock from SERDES
  input  logic       reset,
  output logic       eth_ready,

  // input data (TX)
  input  logic       valid_in,
  input  logic [7:0] data_in,
  input  logic       eof_in,
  output logic       pause_in,

  // output data (RX)
  output logic       valid_out,
  output logic [7:0] data_out,

  // SERDES interface
  input  logic [9:0] rx_data,
  output logic       rx_bitslip,
  output logic [9:0] tx_data
);

  localparam
    K28_5 = 8'hBC, // comma
    D5_6  = 8'hC5, // idle 1
    D16_2 = 8'h50, // idle 2
    K27_7 = 8'hFB, // start of frame
    K29_7 = 8'hFD, // end of frame
    K23_7 = 8'hF7, // carrier extend
    K30_7 = 8'hFE, // error prop
    D21_5 = 8'hB5, // config 1
    D2_2  = 8'h42; // config 2

  logic rx_ready;

  assign eth_ready = rx_ready;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////
  //// RX Channel //////////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////////
  
  logic       rx_even, rx_set_even;
  logic       comma;
  logic [3:0] offset;
  logic [7:0] dec_data;
  logic [7:0] dec_ctrl;

  comma_align comma_align_i (
    .clk,
    .reset,
    .input_data(rx_data),
    .offset,
    .comma
  );

  decoder_8b10b decoder_8b10b_i (
    .input_data(rx_data),
    .output_data(dec_data),
    .output_ctrl(dec_ctrl)
  );

  // RX FSM
  // processes control seq (k ordered sets)
  enum {
    RX_LOS,
    RX_CD1,
    RX_CD2,
    RX_CD3,
    RX_CTRL,
    RX_CFG_IDLE,
    RX_CFG1,
    RX_CFG2,
    RX_SOF,
    RX_PACKET,
    RX_EXT
  } rx_state, next_rx_state;

  always_ff @(posedge clk) begin
    if (reset) rx_state <= RX_LOS;
    else       rx_state <= next_rx_state;

    if (rx_set_even) rx_even <= 0; // setting this cycle even means next cycle must be odd
    else             rx_even <= ~rx_even;
  end

  always_comb begin
    next_rx_state = rx_state;
    rx_ready = 0;
    rx_bitslip = 0;
    rx_set_even = 0;
    valid_out = 0;

    case (rx_state)
      RX_LOS : begin // LOSS_OF_SYNC
        rx_bitslip = |offset;

        if (comma && ~|offset) begin
          rx_set_even = 1;
          next_rx_state = RX_CD1;
        end
      end

      RX_CD1 : begin
        if (comma && (~rx_even || |offset))
          next_rx_state = RX_LOS;
        else if (comma)
          next_rx_state = RX_CD2;
      end
      RX_CD2 : begin
        if (comma && (~rx_even || |offset))
          next_rx_state = RX_LOS;
        else if (comma)
          next_rx_state = RX_CD3;
      end
      RX_CD3 : begin
        if (comma && (~rx_even || |offset))
          next_rx_state = RX_LOS;
        else if (comma)
          next_rx_state = RX_CFG_IDLE;
      end

      RX_CTRL : begin
        rx_ready = 1;
        if (~rx_even)
          next_rx_state = RX_LOS;
        else if (comma && ~|offset)
          next_rx_state = RX_CFG_IDLE;
        else if (dec_ctrl == K27_7)
          next_rx_state = RX_SOF;
        else
          next_rx_state = RX_LOS;
      end

      // read data code group to determine if this is a config or idle seq
      RX_CFG_IDLE : begin
        rx_ready = 1;
        case (dec_data)
          D5_6,
          D16_2: next_rx_state = RX_CTRL;
          D21_5,
          D2_2 : next_rx_state = RX_CFG1;
          default;
        endcase
      end

      RX_CFG1 : begin
        rx_ready = 1;
        next_rx_state = RX_CFG2;
      end
      RX_CFG2 : begin
        rx_ready = 1;
        next_rx_state = RX_CTRL;
      end

      RX_SOF : begin
        rx_ready = 1;
        next_rx_state = RX_PACKET;
      end

      RX_PACKET : begin
        rx_ready = 1;
        if (dec_ctrl == K29_7) // end of frame
          next_rx_state = RX_EXT;
        else
          valid_out = 1;
      end

      RX_EXT : begin
        rx_ready = 1;
        next_rx_state = rx_even ? RX_EXT : RX_CTRL;
      end
    endcase
  end

  assign data_out = dec_data;



  //////////////////////////////////////////////////////////////////////////////////////////////////////////
  //// TX Channel //////////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////////
  
  logic tx_buffer_valid;
  logic tx_buffer_ready;
  logic [7:0] tx_buffer_data;
  logic tx_buffer_eof;

  logic       tx_even;
  logic       control_symbol;
  logic       tx_rd;
  logic [7:0] tx_char;
  logic [2:0] preamble_cnt;
  
  enum {
    IDLE1,
    IDLE2,
    SOF,
    PREAMBLE,
    FRAME,
    EOF,
    C_EXT,
    INTER_FRAME // TODO
  } tx_state, next_tx_state;

  always_ff @(posedge clk) begin
    if (reset) tx_state <= IDLE1;
    else       tx_state <= next_tx_state;

    if (reset) tx_even <= 1;
    else       tx_even <= ~tx_even;

    if (reset) 
      preamble_cnt <= 0;
    else if (tx_state == PREAMBLE)
      preamble_cnt <= preamble_cnt + 1;
  end

  always_comb begin
    next_tx_state = tx_state;
    control_symbol = 0;
    tx_char = 0;
    tx_buffer_ready = 0;

    case (tx_state)
      IDLE1 : begin
        control_symbol = 1;
        tx_char = K28_5;
        next_tx_state = IDLE2;
      end

      IDLE2 : begin
        tx_char = tx_rd ? D16_2 : D5_6;

        if (tx_buffer_valid)
          next_tx_state = SOF;
        else
          next_tx_state = IDLE1;
      end

      SOF : begin
        control_symbol = 1;
        tx_char = K27_7;
        next_tx_state = PREAMBLE;
      end
      
      PREAMBLE : begin
        if (preamble_cnt == 3'h7) begin
          tx_char = 8'hD5;
          next_tx_state = FRAME;
        end else begin
          tx_char = 8'h55;
        end
      end

      FRAME : begin
        tx_buffer_ready = 1;
        tx_char = tx_buffer_data;
        if (tx_buffer_eof || ~tx_buffer_valid) // TODO notify MAC of buffer underrun?
          next_tx_state = EOF;
      end

      EOF : begin
        control_symbol = 1;
        tx_char = K29_7;
        next_tx_state = C_EXT;
      end

      C_EXT : begin
        control_symbol = 1;
        tx_char = K23_7;
        next_tx_state = tx_buffer_valid ? SOF
                      : tx_even ? C_EXT : IDLE1;
      end
    endcase
  end


  encoder_8b10b encoder_8b10b_1 (
    .clk(clk),
    .reset,
    .input_valid(1'b1),
    .input_ctrl(control_symbol), // sel if input char should be encoded as a control symbol
    .input_data(tx_char),
    .output_data(tx_data),
    .rd(tx_rd)
  );


  fifo #(
    .WIDTH(9),
    .DEPTH(16),
    .ALMOST_FULL_THRESHOLD(2)
  ) tx_fifo (
    .clk,
    .reset,
    .ready_in(),
    .valid_in(valid_in && ~pause_in),
    .data_in({eof_in,data_in}),
    .ready_out(tx_buffer_ready),
    .valid_out(tx_buffer_valid),
    .data_out({tx_buffer_eof,tx_buffer_data}),
    .almost_full(pause_in),
    .almost_empty()
  );

endmodule : sgmii_pcs
