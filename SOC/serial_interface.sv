// serial interface for custom SOC

module serial_interface #(CLK_RATE=50_000_000, BAUD_RATE=115200) (
  input  logic clk,
  input  logic reset,

  // UART
  input  logic urx,
  output logic utx,

  // CONTROL BUS (AXI Master)
  // input (read)
  input  logic                  m_axi_arready,
  output logic                  m_axi_arvalid,
  output logic [ADDR_WIDTH-1:0] m_axi_araddr,

  output logic                  m_axi_rready,
  input  logic                  m_axi_rvalid,
  input  logic [31:0]           m_axi_rdata,
  input  logic [1:0]            m_axi_rresp,

  // output (write)
  input  logic                  m_axi_awready,
  output logic                  m_axi_awvalid,
  output logic [ADDR_WIDTH-1:0] m_axi_awaddr,

  input  logic                  m_axi_wready,
  output logic                  m_axi_wvalid,
  output logic [3:0]            m_axi_wstrb,
  output logic [31:0]           m_axi_wdata,

  output logic                  m_axi_bready,
  input  logic                  m_axi_bvalid,
  input  logic [1:0]            m_axi_bresp
);

  localparam ADDR_WIDTH = 32;

  localparam
    START_FRAME = 8'h7E,
    ACK = 8'h06,
    NAK = 8'h15,
    BCMD = 8'h16,
    STALL = 8'h17;

  typedef enum logic [7:0] {
    CMD_WRITE = 8'h00,
    CMD_READ = 8'h01
  } cmd_t;
  
  
  // control signals
  logic crc_reset, crc_error;
  logic payload_en;
  logic pad_zeros;
  logic [7:0]  idx, pkt_remaining;
  logic [1:0]  r_idx;
  cmd_t        cmd;
  logic [7:0]  pkt_len, trans_remaining;
  logic [31:0] address;
  logic clear_write_buffer;
  logic cmd_valid;
  logic axi_write_error;
  logic axi_read_error;
  logic [31:0] i_addr;

  // receive channel signals
  logic rx_valid;
  logic rx_ready;
  logic rx_sample;
  logic [7:0] rx_data;
  logic [7:0] pack_data;

  logic rx_adapter_out_ready;
  logic rx_adapter_out_valid;
  logic [31:0] rx_adapter_out_data;

  logic rx_buffer_out_ready;
  logic rx_buffer_out_valid;
  logic [31:0] rx_buffer_out_data;

  logic axi_write_ready;
  logic axi_write_valid;


  // response channel signals
  logic tx_ready;
  logic tx_valid;
  logic [7:0] tx_data;

  logic tx_adapter_out_ready;
  logic tx_adapter_out_valid;
  logic [7:0] tx_adapter_out_data;

  logic tx_adapter_in_ready;
  logic tx_adapter_in_valid;
  logic [31:0] tx_adapter_in_data;

  logic tx_buffer_in_ready;
  logic tx_buffer_in_valid;
  logic [31:0] tx_buffer_in_data;

  logic axi_read_ready;
  logic axi_read_valid;


  ///////////////////////////////////
  //// Control FSM //////////////////
  ///////////////////////////////////

  enum {
    IDLE,
    CMD,
    ADDR,
    LEN,
    PAYLOAD,
    PACK_ZERO,
    CRC,
    TX_ACK,
    WRITE,
    READ,
    CRC_ERROR,
    BADCMD_ERROR,
    STALL_ERROR
  } state, next_state;

  always_ff @(posedge clk)
    if (reset) state <= IDLE;
    else       state <= next_state;

  always_comb begin
    next_state = state;
    rx_ready = 1;
    crc_reset = 0;
    payload_en = 0;
    pad_zeros = 0;
    pack_data = '0;

    clear_write_buffer = 0;
    cmd_valid = 0;


    // TX signals
    tx_adapter_out_ready = tx_ready;
    tx_valid = tx_adapter_out_valid;
    tx_data = tx_adapter_out_data;


    case (state)
      IDLE : begin 
        if (rx_valid && (rx_data == START_FRAME))
          next_state = CMD;
      end

      CMD : begin
        if (rx_valid)
          case (rx_data)
            CMD_WRITE : next_state = ADDR;
            CMD_READ : next_state = ADDR;
            default : next_state = BADCMD_ERROR;
          endcase
      end

      ADDR : begin
        if (rx_valid && idx == 0)
          next_state = LEN;
      end

      LEN : begin
        if (rx_valid)
          next_state = |rx_data ? PAYLOAD : CRC;
      end

      PAYLOAD : begin
        payload_en = 1;
        pack_data = rx_data;

        if (rx_valid && idx == 0)
          next_state = |r_idx ? PACK_ZERO : CRC;
      end

      PACK_ZERO : begin
        pad_zeros = 1;
        pack_data = '0;

        if (idx == 0)
          next_state = CRC;
      end

      CRC : begin
        if (rx_valid && idx == 0) begin
          crc_reset = 1;
          next_state = IDLE;
          clear_write_buffer = crc_error;
          cmd_valid = ~crc_error;

          if (crc_error)
            next_state = CRC_ERROR;
          // TODO: buffer full error
          else
            next_state = TX_ACK;
        end
      end

      TX_ACK : begin
        tx_adapter_out_ready = 0;
        tx_valid = 1;
        tx_data = ACK;

        if (tx_ready)
          if (cmd == CMD_WRITE)
            next_state = WRITE;
          else if (cmd == CMD_READ)
            next_state = READ;
      end

      READ,
      WRITE : begin
        if (i_state == I_IDLE)
          next_state = IDLE;
      end


      // CRC of command was invalid
      CRC_ERROR : begin
        tx_adapter_out_ready = 0;
        tx_valid = 1;
        tx_data = NAK;

        if (tx_ready)
          next_state = IDLE;
      end

      // invalid opcode
      BADCMD_ERROR : begin
        tx_adapter_out_ready = 0;
        tx_valid = 1;
        tx_data = BCMD;

        if (tx_ready)
          next_state = IDLE;
      end

      // write buffer is full, cant accept new data
      STALL_ERROR : begin
        tx_adapter_out_ready = 0;
        tx_valid = 1;
        tx_data = STALL;

        if (tx_ready)
          next_state = IDLE;
      end
    endcase
  end

  always_ff @(posedge clk) begin
    case (state)
      CMD : begin
        idx <= 3;
        if (rx_valid)
          cmd <= cmd_t'(rx_data);
      end

      ADDR : begin
        if (rx_valid) begin
          address[8*idx+:8] <= rx_data;
          idx <= idx - 1;
        end
      end

      LEN : begin
        if (rx_valid) begin
          if (|rx_data) begin
            idx <= rx_data - 1;
            r_idx <= 3'b100 - rx_data[1:0];
          end else begin
            idx <= 1;
          end
          
          case (cmd)
            CMD_WRITE : pkt_len <= rx_data;
            CMD_READ : pkt_len <= 0;
            default;
          endcase
        end
      end

      PAYLOAD : begin
        if (rx_valid) begin
          if (idx == 0)
            if (|r_idx)
              idx <= r_idx - 1;
            else
              idx <= 1;
          else
            idx <= idx - 1;
        end
      end

      PACK_ZERO : begin
        if (idx == 0)
          idx <= 1;
        else
          idx <= idx - 1;
      end

      CRC : begin
        if (rx_valid) begin
          if (idx == 0) begin
            idx <= 1;
          end else
            idx <= idx - 1;
        end
      end
    endcase
  end


  ///////////////////////////////////
  //// interface FSM ////////////////
  // drives axi interfaces //////////
  ///////////////////////////////////

  enum {
    I_IDLE,
    I_WRITE,
    I_READ
  } i_state, next_i_state;

  always_ff @(posedge clk)
    if (reset) i_state <= I_IDLE;
    else       i_state <= next_i_state;

  always_comb begin
    next_i_state = i_state;
    rx_buffer_out_ready = 0;
    axi_write_valid = 0;
    
    axi_read_valid = 0;

    case (i_state)
      I_IDLE : begin
        if (cmd_valid) begin
          if (cmd == CMD_WRITE)
            next_i_state = I_WRITE;
          else if (cmd == CMD_READ)
            next_i_state = I_READ;
        end
      end

      I_WRITE : begin
        if (axi_write_error) begin
          // TODO
        end else begin
          rx_buffer_out_ready = axi_write_ready;
          axi_write_valid = rx_buffer_out_valid;

          if (axi_write_ready && rx_buffer_out_valid && (trans_remaining == 0))
            next_i_state = I_IDLE;
        end
      end

      I_READ : begin
        if (axi_read_error) begin
          // TODO
        end else begin
          axi_read_valid = 1;

          if (axi_read_ready && (trans_remaining == 0))
            next_i_state = I_IDLE;
        end
      end

    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      i_addr <= 0;
    end else begin
      case (i_state)
        I_IDLE : begin
          if (cmd_valid) begin
            i_addr <= address;
            // trans_remaining = ceil(pkt_len / 4) - 1
            if (~|pkt_len)
              trans_remaining <= 0;
            else if (|pkt_len[1:0])
              trans_remaining <= pkt_len >> 2;
            else
              trans_remaining <= (pkt_len >> 2) - 1;
          end
        end

        I_WRITE : begin
          if (axi_write_ready && axi_write_valid) begin
            i_addr <= i_addr + 4;
            trans_remaining <= ~|trans_remaining ? 0 : trans_remaining - 1;
          end
        end

        I_READ : begin
          if (axi_read_ready && axi_read_valid) begin
            i_addr <= i_addr + 4;
            trans_remaining <= ~|trans_remaining ? 0 : trans_remaining - 1;
          end
        end
      endcase
    end
  end


  ///////////////////////////////////
  //// Write Path ///////////////////
  ///////////////////////////////////

  uart_rx #(.CLK_RATE(CLK_RATE), .BAUD_RATE(BAUD_RATE)) uart_rx_i (.clk, .reset, .rx(urx), .data(rx_data), .ready(rx_ready), .valid(rx_valid), .sample(rx_sample), .baud_rate_error()); 
  crc16 crc16_i (.clk, .reset(crc_reset | reset), .valid(rx_sample), .data(urx), .crc_error);


  bus_width_increase #(.SIZE_IN(8), .SIZE_OUT(32)) pack_bytes (
    .clk,
    .reset,
    .input_ready(),
    .input_valid((rx_valid && payload_en) || pad_zeros),
    .input_data(pack_data),
    .output_ready(rx_adapter_out_ready),
    .output_valid(rx_adapter_out_valid),
    .output_data(rx_adapter_out_data)
  );

  // TODO: size
  fifo #(.WIDTH(32), .DEPTH(8)) write_buffer (
    .clk,
    .reset(reset || clear_write_buffer),
    .ready_in(rx_adapter_out_ready),
    .valid_in(rx_adapter_out_valid),
    .data_in(rx_adapter_out_data),
    .ready_out(rx_buffer_out_ready),
    .valid_out(rx_buffer_out_valid),
    .data_out(rx_buffer_out_data),
    .almost_full(),
    .almost_empty()
  );

  axi_lite_write_master axi_write_interface (
    .clk,
    .reset,
    .error(axi_write_error),
    .ready(axi_write_ready),
    .valid(axi_write_valid),
    .address(i_addr),
    .data(rx_buffer_out_data),
    .m_axi_awready,
    .m_axi_awvalid,
    .m_axi_awaddr,
    .m_axi_wready,
    .m_axi_wvalid,
    .m_axi_wstrb,
    .m_axi_wdata,
    .m_axi_bready,
    .m_axi_bvalid,
    .m_axi_bresp
  );



  ///////////////////////////////////
  //// Read Path ////////////////////
  ///////////////////////////////////

  uart_tx #(.CLK_RATE(CLK_RATE), .BAUD_RATE(BAUD_RATE)) uart_tx_i (.clk, .reset, .tx(utx), .data(tx_data), .ready(tx_ready), .valid(tx_valid));
  
  bus_width_decrease #(.SIZE_IN(32), .SIZE_OUT(8)) unpack_bytes (
    .clk,
    .reset,
    .input_ready(tx_adapter_in_ready),
    .input_valid(tx_adapter_in_valid),
    .input_data(tx_adapter_in_data),
    .output_ready(tx_adapter_out_ready),
    .output_valid(tx_adapter_out_valid),
    .output_data(tx_adapter_out_data)
  );

  // TODO: size
  fifo #(.WIDTH(32), .DEPTH(8)) read_buffer (
    .clk,
    .reset,
    .ready_in(tx_buffer_in_ready),
    .valid_in(tx_buffer_in_valid),
    .data_in(tx_buffer_in_data),
    .ready_out(tx_adapter_in_ready),
    .valid_out(tx_adapter_in_valid),
    .data_out(tx_adapter_in_data),
    .almost_full(),
    .almost_empty()
  );

  axi_lite_read_master axi_read_interface (
    .clk,
    .reset,
    .error(axi_read_error),
    .addr_ready(axi_read_ready),
    .addr_valid(axi_read_valid),
    .addr(i_addr),
    .data_ready(tx_buffer_in_ready),
    .data_valid(tx_buffer_in_valid),
    .data(tx_buffer_in_data),
    .m_axi_arready,
    .m_axi_arvalid,
    .m_axi_araddr,
    .m_axi_rready,
    .m_axi_rvalid,
    .m_axi_rdata,
    .m_axi_rresp
  );

endmodule : serial_interface
