module axi_over_ethernet (
  input  logic       clk,
  input  logic       reset,

  output logic       pcs_locked,

  // AXI

  // SERDES interface
  input  logic       serdes_rx_clk,
  input  logic [9:0] serdes_rx_data,
  output logic       serdes_rx_bitslip,
  output logic [9:0] serdes_tx_data
);

  logic       rx_ready;
  logic       rx_valid;
  logic [7:0] rx_data;
  logic       rx_eof;
  logic       tx_ready;
  logic       tx_valid;
  logic [7:0] tx_data;
  logic       tx_eof;

  mini_mac eth_mac (
    .clk,  // 125MHz clock
    .reset,
    .pcs_locked,
    // RX payload interface
    .ready_out(rx_ready || rx_discard),
    .valid_out(rx_valid),
    .data_out(rx_data),
    .eof_out(rx_eof),
    // TX payload interface
    .ready_in(tx_ready),
    .valid_in(tx_valid),
    .data_in(tx_data),
    .eof_in(tx_eof),
    // SERDES interface
    .rx_clk(serdes_rx_clk),
    .rx_data(serdes_rx_data),
    .rx_bitslip(serdes_rx_bitslip),
    .tx_data(serdes_tx_data)
  );

  typedef enum logic [7:0] {
    OP_WRITE = 8'h10,
    OP_WRITE_ACK = 8'h11,
    OP_READ = 8'h20,
    OP_READ_RSP = 8'h21
  } opcode_t;

  enum {
    SER_IDLE,
    SER_OP,
    SER_SEQ_NUM,
    SER_ADDR,
    SER_LEN,
    SER_WRITE,
    SER_WRITE_ACK,
    SER_WRITE_ACK_SEQ,
    SER_READ_RSP_OP,
    SER_READ_RSP_SEQ,
    SER_READ_RSP_ADDR,
    SER_READ_RSP_LEN,
    SER_READ_RSP_DATA,
    SER_READ_RSP_EOF,
    SER_DISCARD
  } serial_state, next_serial_state;

  // Reliable Serial Protocol decode
  logic update_opcode;
  logic update_seq_num;
  logic update_address;
  logic update_payload_len;
  logic address_incr;
  logic payload_len_decr;
  opcode_t opcode;
  logic [15:0] seq_num;
  logic [31:0] address;
  logic [15:0] payload_len;
  logic [4:0] idx, next_idx;

  logic rx_discard, rx_ignore_pad;


  always_ff @(posedge clk) begin
    if (reset) serial_state <= SER_IDLE;
    else       serial_state <= next_serial_state;
  end

  always_ff @(posedge clk) begin
    idx <= next_idx;

    if (update_opcode)
      opcode <= opcode_t'(rx_data);
    if (update_seq_num)
      seq_num[idx*8+:8] <= rx_data;

    if (update_payload_len)
      payload_len[idx*8+:8] <= rx_data;
    else if (payload_len_decr)
      payload_len <= payload_len - 1;
    
    if (update_address)
      address[idx*8+:8] <= rx_data;
    else if (address_incr)
      address <= address + 1;
  end

  always_ff @(posedge clk) begin
    if (reset || rx_eof)
      rx_discard <= 0;
    else if (rx_ignore_pad)
      rx_discard <= 1;
  end

  always_comb begin
    next_serial_state = serial_state;
    next_idx = idx;
    rx_ready = 0;
    rx_ignore_pad = 0;
    update_opcode = 0;
    update_seq_num = 0;
    update_address = 0;
    update_payload_len = 0;
    payload_len_decr = 0;
    address_incr = 0;
    tx_valid = 0;
    tx_data = 0;
    tx_eof = 0;

    // temp
    ram_addr = 0;
    ram_we = 0;

    case (serial_state)
      SER_IDLE : begin
        if (rx_valid)
          next_serial_state = SER_OP;
      end
      
      SER_OP : begin
        rx_ready = 1;
        update_opcode = 1;
        next_idx = 1;
        next_serial_state = SER_SEQ_NUM;
      end
      
      SER_SEQ_NUM : begin
        rx_ready = 1;
        update_seq_num = 1;
        if (idx == 0) begin
          next_idx = 3;
          next_serial_state = SER_ADDR;
        end else begin
          next_idx = idx - 1;
        end
      end
      
      SER_ADDR : begin
        rx_ready = 1;
        update_address = 1;
        if (idx == 0) begin
          next_idx = 1;
          next_serial_state = SER_LEN;
        end else begin
          next_idx = idx - 1;
        end 
      end
      
      SER_LEN : begin
        rx_ready = 1;
        update_payload_len = 1;
        if (idx == 0) begin
          case (opcode)
            OP_WRITE : next_serial_state = SER_WRITE;
            OP_READ : next_serial_state = SER_READ_RSP_OP;
            default : next_serial_state = SER_DISCARD;
          endcase
        end else begin
          next_idx = idx - 1;
        end 
      end
      
      SER_WRITE : begin
        rx_ready = 1;
        payload_len_decr = 1;
        address_incr = 1;
        ram_we = 1; // temp
        ram_addr = address; // TEMP

        if (payload_len == 1)
          next_serial_state = SER_WRITE_ACK;
      end

      SER_WRITE_ACK : begin
        tx_valid = 1;
        tx_data = OP_WRITE_ACK;
        if (tx_ready) begin
          next_idx = 1;
          next_serial_state = SER_WRITE_ACK_SEQ;
        end
      end

      SER_WRITE_ACK_SEQ : begin
        tx_valid = 1;
        tx_data = seq_num[idx*8+:8];
        if (tx_ready) begin
          if (idx == 0) begin
            next_serial_state = SER_IDLE;
            tx_eof = 1;
          end else begin
            next_idx = idx - 1;
          end
        end
      end

      SER_READ_RSP_OP : begin
        rx_ignore_pad = 1;
        tx_valid = 1;
        tx_data = OP_READ_RSP;
        if (tx_ready) begin
          next_idx = 1;
          next_serial_state = SER_READ_RSP_SEQ;
        end
      end

      SER_READ_RSP_SEQ : begin
        tx_valid = 1;
        tx_data = seq_num[idx*8+:8];
        if (tx_ready) begin
          if (idx == 0) begin
            next_idx = 3;
            next_serial_state = SER_READ_RSP_ADDR;
          end else begin
            next_idx = idx - 1;
          end
        end
      end

      SER_READ_RSP_ADDR : begin
        tx_valid = 1;
        tx_data = address[idx*8+:8];
        if (tx_ready) begin
          if (idx == 0) begin
            next_idx = 1;
            next_serial_state = SER_READ_RSP_LEN;
          end else begin
            next_idx = idx - 1;
          end
        end
      end

      SER_READ_RSP_LEN : begin
        tx_valid = 1;
        tx_data = payload_len[idx*8+:8];
        if (tx_ready) begin
          if (idx == 0) begin
            payload_len_decr = 1;
            address_incr = 1;
            ram_addr = address; // TEMP
            next_idx = 1;
            next_serial_state = SER_READ_RSP_DATA;
          end else begin
            next_idx = idx - 1;
          end
        end
      end
      
      SER_READ_RSP_DATA : begin
        if (idx != 0)
          next_idx = idx - 1;
        tx_valid = (idx == 0);
        tx_data = ram_r_data;
        payload_len_decr = 1;
        address_incr = 1;
        ram_addr = address; // TEMP

        if (payload_len == 0)
          next_serial_state = SER_READ_RSP_EOF;
      end

      SER_READ_RSP_EOF : begin
        tx_valid = 1;
        tx_data = ram_r_data;
        tx_eof = 1;
        next_serial_state = SER_IDLE;
      end

      SER_DISCARD : begin
        rx_ready = 1;
        if (rx_eof)
          next_serial_state = SER_IDLE;
      end
    endcase
  end


  // testing only

  logic          ram_we;
  logic [14-1:0] ram_addr;
  logic [7:0]    ram_r_data, ram_r_data2;




  logic [7:0] ram [(1<<14)-1:0];

  always_ff @(posedge clk) begin
    if (ram_we)
      ram[ram_addr] <= rx_data;
    ram_r_data2 <= ram[ram_addr];
  end 
  always_ff @(posedge clk) begin
    ram_r_data <= ram_r_data2;
  end
   



/*   bram bram64MB (
    .data    (rx_data),    //   input,   width = 8,    data.datain
    .q       (ram_r_data),       //  output,   width = 8,       q.dataout
    .address (ram_addr), //   input,  width = 24, address.address
    .wren    (ram_we),    //   input,   width = 1,    wren.wren
    .clock   (clk)    //   input,   width = 1,   clock.clk
  ); */

endmodule : axi_over_ethernet
