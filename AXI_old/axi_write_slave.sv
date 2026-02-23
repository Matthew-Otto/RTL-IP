module axi_write_slave #(
  ADDR_WIDTH=32, 
  DATA_WIDTH=32,
  ID_WIDTH=1,
  ADDRESS=0
)(
  input  logic                      clk,
  input  logic                      reset,

  input  logic                      output_ready,
  output logic                      output_valid,
  output logic [DATA_WIDTH-1:0]     output_data,

  // AXI write channel
  output logic                      s_axi_awready,
  input  logic                      s_axi_awvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr,
  input  logic [ID_WIDTH-1:0]       s_axi_awid,
  input  logic [7:0]                s_axi_awlen,
  input  logic [2:0]                s_axi_awsize,
  input  logic [1:0]                s_axi_awburst,

  output logic                      s_axi_wready,
  input  logic                      s_axi_wvalid,
  input  logic [DATA_WIDTH-1:0]     s_axi_wdata,
  input  logic [DATA_WIDTH/8-1:0]   s_axi_wstrb,
  input  logic                      s_axi_wlast,

  input  logic                      s_axi_bready,
  output logic                      s_axi_bvalid,
  output logic [ID_WIDTH-1:0]       s_axi_bid,
  output logic [1:0]                s_axi_bresp
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

  localparam ADDR_SUBWORD_BITS = $clog2(DATA_WIDTH/8);


  logic addr_error;
  logic size_error;
  logic burst_error;
  logic error;
  logic last;

  assign addr_error = ((s_axi_awaddr >> ADDR_SUBWORD_BITS) != (ADDRESS >> ADDR_SUBWORD_BITS));
  assign size_error = ((1 << s_axi_awsize) > (DATA_WIDTH/8));
  assign burst_error = (s_axi_awburst != BURST_FIXED);

  assign last = s_axi_wready && s_axi_wvalid && s_axi_wlast;

  enum {
    IDLE,
    RECV
  } state, next_state;

  always_ff @(posedge clk) begin
    if (reset) state <= IDLE;
    else       state <= next_state;

    if (s_axi_awready && s_axi_awvalid)
      s_axi_bid <= s_axi_awid;
  end

  always_comb begin
    next_state = state;
    s_axi_awready = 0;
    error = 0;

    case (state)
      IDLE : begin
        s_axi_awready = 1;

        if (s_axi_awvalid) begin
          error = addr_error || size_error || burst_error;
          if (~(s_axi_wready && s_axi_wvalid && last)) begin
            next_state = RECV;
          end
        end
      end

      RECV : begin
        // error = ?
        if (last)
          next_state = IDLE;
      end
    endcase
  end

  enum {
    VALID,
    ERROR,
    RESP_VALID,
    RESP_ERROR
  } resp_state, next_resp_state;

  always_ff @(posedge clk) begin
    if (reset) resp_state <= VALID;
    else       resp_state <= next_resp_state;
  end

  always_comb begin
    next_resp_state = resp_state;
    s_axi_bvalid = 0;
    s_axi_bresp = '0;

    case (resp_state)
      VALID : begin
        if (error && last)
          next_resp_state = RESP_ERROR;
        else if (error)
          next_resp_state = ERROR;
        else if (last)
          next_resp_state = RESP_VALID;
      end

      ERROR : begin
        if (last)
          next_resp_state = RESP_ERROR;
      end

      RESP_VALID : begin
        s_axi_bvalid = 1;
        s_axi_bresp = RSP_OKAY;

        if (s_axi_bready)
          next_resp_state = VALID;
      end

      RESP_ERROR : begin
        s_axi_bvalid = 1;
        s_axi_bresp = RSP_SLVERR;

        if (s_axi_bready)
          next_resp_state = VALID;
      end
    endcase
  end


  assign s_axi_wready = output_ready;
  assign output_valid = s_axi_wvalid;

  always_comb
    for (int i = 0; i < DATA_WIDTH/8; i++)
      output_data[i*8+:8] = s_axi_wstrb[i] ? s_axi_wdata[i*8+:8] : '0;

endmodule : axi_write_slave
