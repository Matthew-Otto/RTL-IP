module dmac #(ADDR_WIDTH=32, BUS_WIDTH=32, ID_WIDTH=1) (
  input  logic                      clk,
  input  logic                      reset,
  input  logic                      transfer_start,

  // Control register port (AXI-Lite Slave)
  output logic                      s_axi_awready,
  input  logic                      s_axi_awvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr,
  input  logic [2:0]                s_axi_awprot,
  output logic                      s_axi_wready,
  input  logic                      s_axi_wvalid,
  input  logic [BUS_WIDTH/8-1:0]    s_axi_wstrb,
  input  logic [BUS_WIDTH-1:0]      s_axi_wdata,
  input  logic                      s_axi_bready,
  output logic                      s_axi_bvalid,
  output logic [1:0]                s_axi_bresp,
  output logic                      s_axi_arready,
  input  logic                      s_axi_arvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_araddr,
  input  logic                      s_axi_rready,
  output logic                      s_axi_rvalid,
  output logic [BUS_WIDTH-1:0]      s_axi_rdata,
  output logic [1:0]                s_axi_rresp,


  // Data port (AXI Master)
  // Read address channel
  input  logic                      m_axi_arready,
  output logic                      m_axi_arvalid,
  output logic [ADDR_WIDTH-1:0]     m_axi_araddr,
  output logic [ID_WIDTH-1:0]       m_axi_arid,
  output logic [7:0]                m_axi_arlen,
  output logic [2:0]                m_axi_arsize,
  output logic [1:0]                m_axi_arburst,
  // Read data channel
  output logic                      m_axi_rready,
  input  logic                      m_axi_rvalid,
  input  logic [BUS_WIDTH-1:0]      m_axi_rdata,
  input  logic [ID_WIDTH-1:0]       m_axi_rid,
  input  logic [1:0]                m_axi_rresp,
  input  logic                      m_axi_rlast,

  // Write address channel
  input  logic                      m_axi_awready,
  output logic                      m_axi_awvalid,
  output logic [ADDR_WIDTH-1:0]     m_axi_awaddr,
  output logic [ID_WIDTH-1:0]       m_axi_awid,
  output logic [7:0]                m_axi_awlen,
  output logic [2:0]                m_axi_awsize,
  output logic [1:0]                m_axi_awburst,
  // Write data channel
  input  logic                      m_axi_wready,
  output logic                      m_axi_wvalid,
  output logic [BUS_WIDTH-1:0]      m_axi_wdata,
  output logic [BUS_WIDTH/8-1:0]    m_axi_wstrb,
  output logic                      m_axi_wlast,
  // Write response channel
  output logic                      m_axi_bready,
  input  logic                      m_axi_bvalid,
  input  logic [ID_WIDTH-1:0]       m_axi_bid,
  input  logic [1:0]                m_axi_bresp
);

  localparam
    RSP_OKAY = 2'b00,
    RSP_EXOKAY = 2'b01,
    RSP_SLVERR = 2'b10,
    RSP_DECERR = 2'b11;

  localparam
    BURST_FIXED = 2'b00,
    BURST_INCR = 2'b01,
    BURST_WRAP = 2'b10;

  ///////////////////////////////////////////////
  //// control regsiters ////////////////////////
  ///////////////////////////////////////////////
  localparam CTRL_REG_CNT = 1;

  logic [BUS_WIDTH-1:0]    ctrl_registers [CTRL_REG_CNT-1:0];
  logic [BUS_WIDTH-1:0]    ctrl_register_write;
  logic [CTRL_REG_CNT-1:0] ctrl_register_wr_en;

  axi_lite_slave_register #(
    .ADDR_WIDTH(),
    .BUS_WIDTH(),
    .REG_CNT(),
    .START_ADDR()
  ) control_registers (
    .clk,
    .reset,
    .s_axi_awready,
    .s_axi_awvalid,
    .s_axi_awaddr,
    .s_axi_awprot,
    .s_axi_wready,
    .s_axi_wvalid,
    .s_axi_wstrb,
    .s_axi_wdata,
    .s_axi_bready,
    .s_axi_bvalid,
    .s_axi_bresp,
    .s_axi_arready,
    .s_axi_arvalid,
    .s_axi_araddr,
    .s_axi_rready,
    .s_axi_rvalid,
    .s_axi_rdata,
    .s_axi_rresp,
    .registers(ctrl_registers),
    .register_write(ctrl_register_write),
    .register_wr_en(ctrl_register_wr_en)
  );

  logic [31:0] dma_control_reg;
  assign dma_control_reg = ctrl_registers[0];



  typedef enum logic [1:0] {
    STATUS_IDLE = 2'b00,
    STATUS_RUNNING = 2'b01,
    STATUS_ERROR = 2'b10
  } dma_status_t;


  
  logic [39:0] instr_rom [255:0];

  initial begin
    instr_rom[0] = 40'h03_00000600; // byte cnt = 256
    instr_rom[1] = 40'h22_00000000; // src width = 32 bit, src addr = 0x800000
    instr_rom[2] = 40'h28_00000001; // src stride = 1
    instr_rom[3] = 40'h32_00001000; // dest width = 32 bit, dest addr = 0x200
    instr_rom[4] = 40'hf8_00000001; // dest stride = 1
    instr_rom[5] = 40'h80_00000000;
    //instr_rom[5] = 40'hc0_00000000;
    //instr_rom[6] = 40'hc0_00000000;
  end


  // first bit marks the end of transfer description
  // second bit is the autostart bit
  // if termination bit is sec but autostart isn't, dma will wait for external start signal

  // if first (autostart) bit is set, transfer will begin after processing that descriptor
  // else, transfer will have to be started via external signal

  enum {
    DECODE_IDLE,
    DECODE_RUNNING
  } decode_state;

  typedef enum logic [7:0] {
    NOP         = 8'b0000_0000,
    HALT        = 8'b1000_0000,
    REPEAT      = 8'b1100_0000, // repeat last transfer
    LOOP        = 8'b??00_0001, // reset instr_addr to 0
    BYTE_CNT    = 8'b??00_0011, // set number of bytes to transfer
    SRC_ADDR    = 8'b??10_0???, // bottom 3 bits is byte width of beat
    SRC_STRIDE  = 8'b??10_1000, // how much to increment the address each beat (word alligned) (TODO: currently unimplemented)
    DEST_ADDR   = 8'b??11_0???, // bottom 3 bits is byte width of beat
    DEST_STRIDE = 8'b??11_1000  // how much to increment the address each beat (word alligned) (TODO: currently unimplemented)
  } descr_op_t;


  logic [31:0] dec_byte_cnt;
  logic [31:0] dec_src_addr;
  logic [2:0]  dec_src_size;
  logic [31:0] dec_src_stride;
  logic [31:0] dec_dest_addr;
  logic [2:0]  dec_dest_size;
  logic [31:0] dec_dest_stride;

  logic [7:0]  instr_addr;
  descr_op_t   opcode;
  logic [31:0] payload;
  logic descr_terminator;
  logic autostart, dec_autostart;
  logic decode_next; // decode next descriptor
  
  assign {opcode, payload} = instr_rom[instr_addr];

  assign descr_terminator = opcode[7];
  assign autostart = opcode[6];

  ///////////////////////////////////////////////////////
  //// DMA Descriptor Decoder ///////////////////////////
  ///////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if (reset) begin
      decode_state <= DECODE_RUNNING;
      decode_next <= 1;
    end else begin
      case (decode_state)
        DECODE_IDLE : begin
          if (dma_start) begin
            dec_autostart <= 0;
            decode_state <= DECODE_RUNNING;
          end
        end

        DECODE_RUNNING : begin
          if (descr_terminator) begin
            dec_autostart <= autostart;
            decode_state <= DECODE_IDLE;
          end

          instr_addr <= instr_addr + 1;

          casez (opcode)
            LOOP : instr_addr <= 0;

            BYTE_CNT : dec_byte_cnt <= payload;

            SRC_ADDR : begin
              dec_src_addr <= payload;
              dec_src_size <= opcode[2:0];
            end

            SRC_STRIDE : dec_src_stride <= payload;

            DEST_ADDR : begin
              dec_dest_addr <= payload;
              dec_dest_size <= opcode[2:0];
            end

            DEST_STRIDE : dec_dest_stride <= payload;

            default;
          endcase
        end
      endcase
    end
  end



  ///////////////////////////////////////////////////////
  //// DMA Address Generator ////////////////////////////
  ///////////////////////////////////////////////////////
  logic dma_start;
  logic [31:0] dma_src_byte_cnt, next_src_byte_cnt;
  logic [31:0] dma_src_addr, next_src_addr;
  logic [31:0] dma_src_stride;
  logic [2:0]  dma_src_size;
  logic [7:0]  dma_src_burst_len;
  logic [31:0] dma_dest_byte_cnt, next_dest_byte_cnt;
  logic [31:0] dma_dest_addr, next_dest_addr;
  logic [31:0] dma_dest_stride;
  logic [2:0]  dma_dest_size;
  logic [7:0]  dma_dest_burst_len;
  logic dma_src_ready, dma_src_valid;
  logic dma_dest_ready, dma_dest_valid;
  logic read_stall, write_stall;
  logic [14:0] max_read_burst_bytes;
  logic [14:0] max_write_burst_bytes;


  assign dma_start = (dec_autostart || transfer_start) && (dma_write_state == DMA_WRITE_IDLE);

  enum {
    DMA_READ_IDLE,
    DMA_READ_ACT,
    DMA_READ_STALL,
    DMA_READ_ERROR
  } dma_read_state, next_dma_read_state;

  always_ff @(posedge clk) begin
    if (reset) begin
      dma_read_state <= DMA_READ_IDLE;
      dma_write_state <= DMA_WRITE_IDLE;
    end else begin
      dma_read_state <= next_dma_read_state;
      dma_write_state <= next_dma_write_state;
    end

    if (reset) begin
      dma_src_byte_cnt <= '0;
      dma_src_addr <= '0;
      dma_dest_byte_cnt <= '0;
      dma_dest_addr <= '0;
    end else begin
      dma_src_byte_cnt <= next_src_byte_cnt;
      dma_src_addr <= next_src_addr;
      dma_dest_byte_cnt <= next_dest_byte_cnt;
      dma_dest_addr <= next_dest_addr;
    end

    // width and stride
    if (reset) begin
      dma_src_size <= '0;
      dma_src_stride <= '0;
      dma_dest_size <= '0;
      dma_dest_stride <= '0;
    end else if (dma_start) begin
      dma_src_size <= dec_src_size;
      dma_src_stride <= dec_src_stride * (1 << dec_src_size);
      dma_dest_size <= dec_dest_size;
      dma_dest_stride <= dec_dest_stride * (1 << dec_dest_size);
    end

    // axi transfer size
    if (dma_start) begin
      m_axi_arsize <= dec_src_size;
      m_axi_awsize <= dec_dest_size;
      max_read_burst_bytes <= 1 << (dec_src_size + 8);
      max_write_burst_bytes <= 1 << (dec_dest_size + 8);
    end

    // axi burst mode
    if (dma_start) begin
      if (dec_src_stride == 0)
        m_axi_arburst <= BURST_FIXED;
      else if (dec_src_stride == 1)
        m_axi_arburst <= BURST_INCR;

      if (dec_dest_stride == 0)
        m_axi_awburst <= BURST_FIXED;
      else if (dec_dest_stride == 1)
        m_axi_awburst <= BURST_INCR;
    end
  end


  enum {
    DMA_WRITE_IDLE,
    DMA_WRITE_ACT,
    DMA_WRITE_STALL,
    DMA_WRITE_ERROR
  } dma_write_state, next_dma_write_state;

  always_comb begin
    next_src_byte_cnt = dma_src_byte_cnt;
    next_src_addr = dma_src_addr;

    dma_src_valid = 0;
    dma_src_burst_len = 0;

    case (dma_read_state)
      DMA_READ_IDLE : begin
        if (dma_start) begin
          next_src_byte_cnt = dec_byte_cnt;
          next_src_addr = dec_src_addr;
          next_dma_read_state = DMA_READ_ACT;
        end
      end

      DMA_READ_ACT : begin
        dma_src_valid = 1;

        if (dma_src_byte_cnt < max_read_burst_bytes)
          dma_src_burst_len = (dma_src_byte_cnt >> dma_src_size) - 1;
        else
          dma_src_burst_len = (max_read_burst_bytes >> dma_src_size) - 1;

        if (dma_src_ready) begin
          // TODO error
          next_src_byte_cnt = dma_src_byte_cnt - max_read_burst_bytes;
          next_src_addr = dma_src_addr + max_read_burst_bytes;
          if (dma_src_byte_cnt < max_read_burst_bytes) begin
            next_src_addr = dma_src_addr + max_read_burst_bytes;
            next_dma_read_state = DMA_READ_IDLE;
          end else if (read_stall) begin
            next_dma_read_state = DMA_READ_STALL;
          end
        end
      end

      DMA_READ_STALL : begin
        if (~read_stall)
          next_dma_read_state = DMA_READ_ACT;
      end

      DMA_READ_ERROR : begin
      end
    endcase
  end

  always_comb begin
    next_dest_byte_cnt = dma_dest_byte_cnt;
    next_dest_addr = dma_dest_addr;

    dma_dest_valid = 0;
    dma_dest_burst_len = 0;

    case (dma_write_state)
      DMA_WRITE_IDLE : begin
        if (dma_start) begin
          next_dest_byte_cnt = dec_byte_cnt;
          next_dest_addr = dec_dest_addr;
          next_dma_write_state = DMA_WRITE_ACT;
        end
      end

      DMA_WRITE_ACT : begin
        dma_dest_valid = 1;

        if (dma_dest_byte_cnt < max_write_burst_bytes)
          dma_dest_burst_len = (dma_dest_byte_cnt >> dma_dest_size) - 1;
        else
          dma_dest_burst_len = (max_write_burst_bytes >> dma_dest_size) - 1;

        if (dma_dest_ready) begin
          // TODO error
          next_dest_byte_cnt = dma_dest_byte_cnt - max_write_burst_bytes;
          next_dest_addr = dma_dest_addr + max_write_burst_bytes;
          if (dma_dest_byte_cnt < max_write_burst_bytes) begin
            next_dest_addr = dma_dest_addr + dma_dest_byte_cnt;
            next_dma_write_state = DMA_WRITE_IDLE;
          end else if (write_stall) begin
            next_dma_write_state = DMA_WRITE_STALL;
          end
        end
      end

      DMA_WRITE_STALL : begin
        if (~write_stall)
          next_dma_write_state = DMA_WRITE_ACT;
      end

      DMA_WRITE_ERROR : begin
      end
    endcase
  end


  fifo #(
    .WIDTH(ADDR_WIDTH+8),
    .DEPTH(8),
    .ALMOST_FULL_THRESHOLD(1)
  ) read_addr_buffer (
    .clk,
    .reset,
    .ready_in(dma_src_ready),
    .valid_in(dma_src_valid),
    .data_in({dma_src_addr,dma_src_burst_len}),
    .almost_full(read_stall),
    .ready_out(m_axi_arready),
    .valid_out(m_axi_arvalid),
    .data_out({m_axi_araddr,m_axi_arlen}),
    .almost_empty()
  );


  fifo #(
    .WIDTH(ADDR_WIDTH+8),
    .DEPTH(8),
    .ALMOST_FULL_THRESHOLD(1)
  ) write_addr_buffer (
    .clk,
    .reset,
    .ready_in(dma_dest_ready),
    .valid_in(dma_dest_valid),
    .data_in({dma_dest_addr,dma_dest_burst_len}),
    .almost_full(write_stall),
    .ready_out(write_addr_ready),
    .valid_out(write_addr_valid),
    .data_out({m_axi_awaddr,m_axi_awlen}),
    .almost_empty()
  );

  fifo #(
    .WIDTH(BUS_WIDTH),
    .DEPTH(8)
  ) write_data_buffer (
    .clk,
    .reset,
    .ready_in(m_axi_rready),
    .valid_in(m_axi_rvalid),
    .data_in(m_axi_rdata),
    .ready_out(m_axi_wready),
    .valid_out(m_axi_wvalid),
    .data_out(m_axi_wdata),
    .almost_full(),
    .almost_empty()
  );

  logic write_addr_ready;
  logic write_addr_valid;
  logic gate_wr_addr_n;
  logic [7:0] burst_remaining;

  assign write_addr_ready = m_axi_awready && gate_wr_addr_n;
  assign m_axi_awvalid = write_addr_valid && gate_wr_addr_n;
  assign gate_wr_addr_n = (burst_remaining == 0);
  assign m_axi_wlast = (burst_remaining == 0);

  always_ff @(posedge clk) begin
    if (reset)
      burst_remaining <= 0;
    else begin
      if (write_addr_ready && write_addr_valid)
        burst_remaining <= m_axi_awlen;
      if (m_axi_wready && m_axi_wvalid && ~(burst_remaining == 0))
        burst_remaining <= burst_remaining - 1;
    end
  end

  assign m_axi_bready = 1;

  assign m_axi_wstrb = '1; // TODO

endmodule : dmac
