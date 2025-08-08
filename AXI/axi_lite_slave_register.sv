// basic register(s) that can be access vie axi-lite port

module axi_lite_slave_register #(ADDR_WIDTH=32, DATA_WIDTH=32, REG_CNT=1, START_ADDR=4) (
  input  logic                      clk,
  input  logic                      reset,

  // write
  output logic                      s_axi_awready,
  input  logic                      s_axi_awvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr,
  input  logic [2:0]                s_axi_awprot,
  output logic                      s_axi_wready,
  input  logic                      s_axi_wvalid,
  input  logic [3:0]                s_axi_wstrb,
  input  logic [31:0]               s_axi_wdata,
  input  logic                      s_axi_bready,
  output logic                      s_axi_bvalid,
  output logic [1:0]                s_axi_bresp,

  // read
  output logic                      s_axi_arready,
  input  logic                      s_axi_arvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_araddr,

  input  logic                      s_axi_rready,
  output logic                      s_axi_rvalid,
  output logic [31:0]               s_axi_rdata,
  output logic [1:0]                s_axi_rresp,

  output logic [DATA_WIDTH-1:0]     registers [REG_CNT-1:0],
  input  logic [DATA_WIDTH-1:0]     register_write, // register writes overwrite axi writes in the same cycle
  input  logic [REG_CNT-1:0]        register_wr_en 
);

  localparam WORD_OFFSET = DATA_WIDTH / 8;
  localparam ADDR_ALIGN = $clog2(WORD_OFFSET);
  localparam BASE_ALIGN_ADDR = START_ADDR >> ADDR_ALIGN;
  localparam END_ALIGN_ADDR = BASE_ALIGN_ADDR + REG_CNT - 1;

  // Ensure START_ADDR is word alligned
  generate
    if ((START_ADDR & ((1 << ADDR_ALIGN) - 1)) != 0) begin
      initial $fatal(1, "START_ADDR (0x%0h) is not aligned to DATA_WIDTH (%0d bytes)", START_ADDR, (1 << ADDR_ALIGN));
    end
  endgenerate

  localparam
    RSP_OKAY = 2'b00,
    RSP_EXOKAY = 2'b01,
    RSP_SLVERR = 2'b10,
    RSP_DECERR = 2'b11;

  logic [3:0]            wr_en [REG_CNT-1:0];
  logic [ADDR_WIDTH-1:0] wr_addr;
  logic [3:0]            data_strb_b;
  logic [31:0]           data_b;
  logic [1:0]            resp_b;

  logic [ADDR_WIDTH-ADDR_ALIGN-1:0] alligned_wr_addr;

  assign alligned_wr_addr = wr_addr[ADDR_WIDTH-1:ADDR_ALIGN];

  ///////////////////////////////////////////////////////
  //// AXI-Lite write port //////////////////////////////
  ///////////////////////////////////////////////////////
  enum {
    W_READY,
    W_VALID_ADDR,
    W_VALID_DATA,
    W_REG,
    W_READY_PEND_RSP,
    W_VALID_ADDR_PEND_RSP,
    W_VALID_DATA_PEND_RSP,
    W_REG_PEND_RSP
  } wr_state, next_wr_state;

  always_ff @(posedge clk)
    if (reset) wr_state <= W_READY;
    else       wr_state <= next_wr_state;

  always_comb begin
    next_wr_state = wr_state;
    s_axi_awready = 0;
    s_axi_wready = 0;
    s_axi_bvalid = 0;
    s_axi_bresp = RSP_OKAY;

    for (int i = 0; i < REG_CNT; i++)
      wr_en[i] = '0;

    case (wr_state)
      // buffer is empty, no responses pending
      W_READY : begin
        s_axi_awready = 1;
        s_axi_wready = 1;

        case ({s_axi_awvalid, s_axi_wvalid})
          2'b11 : next_wr_state = W_REG;
          2'b10 : next_wr_state = W_VALID_ADDR;
          2'b01 : next_wr_state = W_VALID_DATA;
          default: next_wr_state = wr_state;
        endcase
      end

      // buffered address, need data
      W_VALID_ADDR : begin
        s_axi_wready = 1;
        if (s_axi_wvalid)
          next_wr_state = W_REG;
      end

      // buffered data, need address
      W_VALID_DATA : begin
        s_axi_awready = 1;
        if (s_axi_awvalid)
          next_wr_state = W_REG;
      end

      // addr + data are valid, write to control register, send response
      W_REG : begin
        s_axi_bvalid = 1;

        // decode valid addresses
        /* verilator lint_off UNSIGNED */
        if ((alligned_wr_addr < BASE_ALIGN_ADDR) || (alligned_wr_addr > END_ALIGN_ADDR))
        /* lint_off */
          s_axi_bresp = RSP_SLVERR;
        else 
          s_axi_bresp = RSP_OKAY;

        // address decode / register wr_en
        for (int i = 0; i < REG_CNT; i++) begin
          for (int j = 0; j < 4; j++) begin
            wr_en[i][j] = (alligned_wr_addr == (i+BASE_ALIGN_ADDR)) && data_strb_b[j];
          end
        end

        s_axi_awready = 1;
        s_axi_wready = 1;

        case ({s_axi_awvalid, s_axi_wvalid, s_axi_bready})
          3'b001 : next_wr_state = W_READY;
          3'b101 : next_wr_state = W_VALID_ADDR;
          3'b011 : next_wr_state = W_VALID_DATA;
          3'b111 : next_wr_state = W_REG;
          3'b000 : next_wr_state = W_READY_PEND_RSP;
          3'b100 : next_wr_state = W_VALID_ADDR_PEND_RSP;
          3'b010 : next_wr_state = W_VALID_DATA_PEND_RSP;
          3'b110 : next_wr_state = W_REG_PEND_RSP;
        endcase
      end

      // buffer empty but pending response
      W_READY_PEND_RSP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = resp_b;

        s_axi_awready = 1;
        s_axi_wready = 1;
        case ({s_axi_awvalid, s_axi_wvalid, s_axi_bready})
          3'b111 : next_wr_state = W_REG;
          3'b101 : next_wr_state = W_VALID_ADDR;
          3'b011 : next_wr_state = W_VALID_DATA;
          3'b001 : next_wr_state = W_READY;
          3'b110 : next_wr_state = W_REG_PEND_RSP;
          3'b100 : next_wr_state = W_VALID_ADDR_PEND_RSP;
          3'b010 : next_wr_state = W_VALID_DATA_PEND_RSP;
          3'b000 : next_wr_state = W_READY_PEND_RSP;
        endcase
      end

      // buffered addr but previous response pending
      W_VALID_ADDR_PEND_RSP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = resp_b;

        s_axi_wready = 1;
        case ({s_axi_wvalid, s_axi_bready})
          2'b10 : next_wr_state = W_REG_PEND_RSP;
          2'b01 : next_wr_state = W_VALID_ADDR;
          2'b11 : next_wr_state = W_REG;
          2'b00 : next_wr_state = W_VALID_ADDR_PEND_RSP;
        endcase
      end

      // buffered data but previous response pending
      W_VALID_DATA_PEND_RSP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = resp_b;

        s_axi_awready = 1;
        case ({s_axi_awvalid, s_axi_bready})
          2'b10 : next_wr_state = W_REG_PEND_RSP;
          2'b01 : next_wr_state = W_VALID_DATA;
          2'b11 : next_wr_state = W_REG;
          2'b00 : next_wr_state = W_VALID_DATA_PEND_RSP;
        endcase
      end

      // valid buffer but previous response pending
      W_REG_PEND_RSP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = resp_b;
        if (s_axi_bready)
          next_wr_state = W_REG;
      end
    endcase
  end

  always_ff @(posedge clk) begin
    // buffer write
    if (s_axi_awready && s_axi_awvalid)
      wr_addr <= s_axi_awaddr;

    if (s_axi_wready && s_axi_wvalid) begin
      data_b <= s_axi_wdata;
      data_strb_b <= s_axi_wstrb;
    end

    if (wr_state == W_REG)
      resp_b <= s_axi_bresp;
  end

  // target registers
  always_ff @(posedge clk) begin
    for (int i = 0; i < REG_CNT; i++) begin
      for (int j = 0; j < DATA_WIDTH; j++) begin
        if (reset)
          registers[i][j] <= '0;
        else if (register_wr_en[i] || wr_en[i][j/8])
          registers[i][j] <= register_wr_en[i] ? register_write[j] : data_b[j];
      end
    end
  end

  ///////////////////////////////////////////////////////
  //// AXI-Lite read port ///////////////////////////////
  ///////////////////////////////////////////////////////

  logic [ADDR_WIDTH-1:0] r_addr;
  logic [ADDR_WIDTH-ADDR_ALIGN-1:0] alligned_axi_addr;
  logic [ADDR_WIDTH-ADDR_ALIGN-1:0] alligned_r_addr;

  assign alligned_axi_addr = s_axi_araddr[ADDR_WIDTH-1:ADDR_ALIGN];
  assign alligned_r_addr = r_addr[ADDR_WIDTH-1:ADDR_ALIGN];

  enum {
    R_READY,
    R_REG,
    R_BADADDR
  } r_state, next_r_state;

  always_ff @(posedge clk) begin
    if (reset) r_state <= R_READY;
    else       r_state <= next_r_state;

    if (s_axi_arready && s_axi_arvalid)
      r_addr <= s_axi_araddr;
  end

  always_comb begin
    next_r_state = r_state;
    s_axi_arready = 0;
    s_axi_rvalid = 0;
    s_axi_rdata = '0;
    s_axi_rresp = '0;

    case (r_state)
      R_READY : begin
        s_axi_arready = 1;

        if (s_axi_arvalid)
          if ((alligned_axi_addr < BASE_ALIGN_ADDR) || (alligned_axi_addr > END_ALIGN_ADDR))
            next_r_state = R_BADADDR;
          else
            next_r_state = R_REG;
      end

      R_REG : begin
        s_axi_rvalid = 1;
        s_axi_rresp = RSP_OKAY;

        for (int i = 0; i < REG_CNT; i++) begin
          if (alligned_r_addr == (i+BASE_ALIGN_ADDR))
            s_axi_rdata = registers[i];
        end

        if (s_axi_rready)
          next_r_state = R_READY;
      end

      R_BADADDR : begin
        s_axi_rvalid = 1;
        s_axi_rresp = RSP_SLVERR;

        if (s_axi_rready)
          next_r_state = R_READY;
      end
    endcase
  end

endmodule : axi_lite_slave_register
