// full AXI interface for SDRAM controller

// mem controller only supports 16 bit alligned accesses for now, so axi interface will also enforce this
// this axi lite interface only supports one pending operation at a time
// if there are both read and write ops pending, the read op is serviced first

module sdram_axi_gpio #(
  FREQ=50000000,
  ADDR_WIDTH=32,
  DATA_WIDTH=32,
  ID_WIDTH=1
) (
  input  logic        clk,
  input  logic        reset,

  // Read address channel
  output logic                      s_axi_arready,
  input  logic                      s_axi_arvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_araddr,
  input  logic [ID_WIDTH-1:0]       s_axi_arid,
  input  logic [7:0]                s_axi_arlen,
  input  logic [2:0]                s_axi_arsize,
  input  logic [1:0]                s_axi_arburst,
  // Read data channel
  input  logic                      s_axi_rready,
  output logic                      s_axi_rvalid,
  output logic [DATA_WIDTH-1:0]     s_axi_rdata,
  output logic [ID_WIDTH-1:0]       s_axi_rid,
  output logic [1:0]                s_axi_rresp,
  output logic                      s_axi_rlast,

  // Write address channel
  output logic                      s_axi_awready,
  input  logic                      s_axi_awvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr,
  input  logic [ID_WIDTH-1:0]       s_axi_awid,
  input  logic [7:0]                s_axi_awlen,
  input  logic [2:0]                s_axi_awsize,
  input  logic [1:0]                s_axi_awburst,
  // Write data channel
  output logic                      s_axi_wready,
  input  logic                      s_axi_wvalid,
  input  logic [DATA_WIDTH-1:0]     s_axi_wdata,
  input  logic [DATA_WIDTH/8-1:0]   s_axi_wstrb,
  input  logic                      s_axi_wlast,
  // Write response channel
  input  logic                      s_axi_bready,
  output logic                      s_axi_bvalid,
  output logic [ID_WIDTH-1:0]       s_axi_bid,
  output logic [1:0]                s_axi_bresp,

  // SDRAM interface
  output logic                      sdram_clk,
  output logic                      sdram_cs,        // two chips
  output logic [1:0]                sdram_bank,      // four banks per chip
  output logic [12:0]               sdram_addr,      // multiplexed address
  output logic                      sdram_ras,       // row address select
  output logic                      sdram_cas,       // column address select
  output logic                      sdram_we,        // write enable
  input  logic [15:0]               sdram_data_in,   // read data
  output logic [15:0]               sdram_data_out,  // write data
  output logic                      sdram_drive_data // tristate driver enable
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

  // Memory Controller interface
  logic        read;
  logic        write;
  logic [1:0]  wr_strb;
  logic [25:0] addr;  // {chip, bank[1:0], row[12:0], col[9:0]}
  logic        cmd_ready;
  logic [15:0] data_write;
  logic [15:0] data_read;
  logic        data_read_val;

  logic                  read_ready;
  logic                  read_valid;
  logic [ADDR_WIDTH-1:0] read_addr;
  logic [ID_WIDTH-1:0]   read_id;
  logic [2:0]            read_size;
  logic [7:0]            read_burst_len;
  logic [1:0]            read_burst_type;

  fifo #(
    .WIDTH(ADDR_WIDTH+ID_WIDTH+13),
    .DEPTH(8)
  ) read_addr_buffer (
    .clk,
    .reset,
    .ready_in(s_axi_arready),
    .valid_in(s_axi_arvalid),
    .data_in({s_axi_araddr, s_axi_arid, s_axi_arlen, s_axi_arsize, s_axi_arburst}),
    .ready_out(read_ready),
    .valid_out(read_valid),
    .data_out({read_addr, read_id, read_burst_len, read_size, read_burst_type}),
    .almost_full(),
    .almost_empty()
  );

  logic                  write_aready;
  logic                  write_avalid;
  logic [ADDR_WIDTH-1:0] write_addr;
  logic [ID_WIDTH-1:0]   write_id;
  logic [2:0]            write_size;
  logic [7:0]            write_burst_len;
  logic [1:0]            write_burst_type;

  logic                    write_ready;
  logic                    write_valid;
  logic [DATA_WIDTH-1:0]   write_data;
  logic [DATA_WIDTH/8-1:0] write_strb;
  logic                    write_last;

  // write channel fifo
  fifo #(
    .WIDTH(ADDR_WIDTH+ID_WIDTH+13),
    .DEPTH(8)
  ) write_addr_buffer (
    .clk,
    .reset,
    .ready_in(s_axi_awready),
    .valid_in(s_axi_awvalid),
    .data_in({s_axi_awaddr, s_axi_awid, s_axi_awlen, s_axi_awsize, s_axi_awburst}),
    .ready_out(write_aready),
    .valid_out(write_avalid),
    .data_out({write_addr, write_id, write_burst_len, write_size, write_burst_type}),
    .almost_full(),
    .almost_empty()
  );
  fifo #(
    .WIDTH(DATA_WIDTH+(DATA_WIDTH/8)+1),
    .DEPTH(8)
  ) write_data_buffer (
    .clk,
    .reset,
    .ready_in(s_axi_wready),
    .valid_in(s_axi_wvalid),
    .data_in({s_axi_wdata, s_axi_wstrb, s_axi_wstrb}),
    .ready_out(write_ready),
    .valid_out(write_valid),
    .data_out({write_data, write_strb, write_last}),
    .almost_full(),
    .almost_empty()
  );


  enum {
    IDLE,
    READ,
    WADDR_PEND,
    WDATA_PEND,
    WRITE
  } axi_state, next_axi_state;

  enum {
    R_IDLE
  } rresp_state, next_rresp_state;

  enum {
    B_IDLE
  } bresp_state, next_bresp_state;

  




  always_ff @(posedge clk)
    if (reset) axi_state <= IDLE;
    else       axi_state <= next_axi_state;

  always_comb begin
    next_axi_state = axi_state;

    read_ready = 0;
    write_aready = 0;
    write_ready = 0;

    read = 0;
    write = 0;
    wr_strb = '0;
    addr = '0;
    data_write = '0;

    s_axi_arready = 0;
    s_axi_rvalid = 0;
    s_axi_rdata = '0;
    s_axi_rid = '0;
    s_axi_rresp = '0;
    s_axi_rlast = 0;
    
    s_axi_awready = 0;
    s_axi_wready = 0;
    s_axi_bvalid = 0;
    s_axi_bid = '0;
    s_axi_bresp = '0;


    case (axi_state)
      IDLE : begin
        if (read_valid) begin
          read_ready = 1;
          next_axi_state = READ;
        end else if (write_avalid) begin
          write_aready = 1;
          next_axi_state = WRITE;
        end
      end

      READ : begin
        read = 1;
        addr = read_addr;
        if (cmd_ready)
          next_axi_state = READ_RSP;
      end

      WAIT_READ_RSP : begin
        if (data_read_val)
          next_axi_state = READ_RSP;
      end

      READ_RSP : begin
        s_axi_rvalid = 1;
        s_axi_rdata = read_data;
        s_axi_rresp = RSP_OKAY;  // TODO: errors?

        if (s_axi_rready)
          case ({valid_aw, valid_w})
            2'b11 : next_axi_state = WRITE;
            2'b10 : next_axi_state = WDATA_PEND;
            2'b01 : next_axi_state = WADDR_PEND;
            2'b00 : next_axi_state = IDLE;
          endcase
      end

      WADDR_PEND : begin
        s_axi_arready = 1;
        if (s_axi_awvalid)
          next_axi_state = WRITE;
      end

      WDATA_PEND : begin
        s_axi_wready = 1;
        if (s_axi_wvalid)
          next_axi_state = WRITE;
      end

      WRITE : begin
        write = 1;
        addr = write_addr;
        if (cmd_ready)
          next_axi_state = WRITE_RESP;
      end

      WRITE_RESP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = RSP_OKAY;  // TODO: errors?
        if (s_axi_rready)
          next_axi_state = IDLE;
      end

    endcase
  end

  always_ff @(posedge clk) begin
    if (reset || (axi_state == IDLE)) begin
      valid_ar <= 0;
      valid_aw <= 0;
      valid_w <= 0;
    end else begin
      if (s_axi_arvalid && s_axi_arready)
        valid_ar <= 1;

      if (s_axi_awready && s_axi_awvalid)
        valid_aw <= 1;

      if (s_axi_wready && s_axi_wvalid)
        valid_w <= 1;
    end
  end

  always_ff @(posedge clk) begin
    if (s_axi_arvalid && s_axi_arready)
      read_addr <= s_axi_araddr;
    
    if (s_axi_awready && s_axi_awvalid)
      write_addr <= s_axi_awaddr;

    if (s_axi_wready && s_axi_wvalid)
      data_write <= s_axi_wdata[15:0]; // TODO strobe

    if (data_read_val)
      read_data <= data_read; // very good, excellent, not bad variable naming
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////////////

  // Write response
  enum {
    BRESP_VALID,
    BRESP_ERROR,
    BRESP_SEND_VALID,
    BRESP_SEND_ERROR
  } write_resp_state, next_write_resp_state;

  always_ff @(posedge clk)
    if (reset) write_resp_state <= BRESP_VALID;
    else       write_resp_state <= next_write_resp_state;

  always_comb begin
    next_write_resp_state = write_resp_state;
    s_axi_bvalid = 0;
    s_axi_bresp = '0;

    case (write_resp_state)
      BRESP_VALID : begin
        if (axi_write_error && s_axi_wlast)
          next_write_resp_state = BRESP_SEND_ERROR;
        else if (axi_write_error)
          next_write_resp_state = BRESP_ERROR;
        else if (s_axi_wlast)
          next_write_resp_state = BRESP_SEND_VALID;
      end

      BRESP_ERROR : begin
        if (s_axi_wlast)
          next_write_resp_state = BRESP_SEND_ERROR;
      end

      BRESP_SEND_VALID : begin
        s_axi_bvalid = 1;
        s_axi_bresp = RSP_OKAY;
        if (s_axi_bready)
          next_write_resp_state = BRESP_VALID;
      end

      BRESP_SEND_ERROR : begin
        s_axi_bvalid = 1;
        s_axi_bresp = RSP_SLVERR;
        if (s_axi_bready)
          next_write_resp_state = BRESP_VALID;
      end
    endcase
  end


  sdram #(.FREQ(FREQ)) sdram_i (
    .clk,
    .reset,
    .read,
    .write,
    .addr,
    .cmd_ready,
    .data_write,
    .data_read,
    .data_read_val,
    .sdram_clk,
    .sdram_cs,
    .sdram_bank,
    .sdram_addr,
    .sdram_ras,
    .sdram_cas,
    .sdram_we,
    .sdram_data_in,
    .sdram_data_out,
    .sdram_drive_data
  );

endmodule : sdram_axi_gpio
