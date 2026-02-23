module axi_read_slave #(
  ADDR_WIDTH=32, 
  DATA_WIDTH=32,
  RUSER_WIDTH=32,
  ID_WIDTH=1,
  ADDRESS=0
)(
  input  logic                      clk,
  input  logic                      reset,

  output logic                      input_ready,
  input  logic                      input_valid,
  input  logic [DATA_WIDTH-1:0]     input_data,
  input  logic [RUSER_WIDTH-1:0]    input_data_user,

  // AXI read channel
  output logic                      s_axi_arready,
  input  logic                      s_axi_arvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_araddr,
  input  logic [ID_WIDTH-1:0]       s_axi_arid,
  input  logic [7:0]                s_axi_arlen,
  input  logic [2:0]                s_axi_arsize,
  input  logic [1:0]                s_axi_arburst,

  input  logic                      s_axi_rready,
  output logic                      s_axi_rvalid,
  output logic [DATA_WIDTH-1:0]     s_axi_rdata,
  output logic [RUSER_WIDTH-1:0]    s_axi_ruser,
  output logic [ID_WIDTH-1:0]       s_axi_rid,
  output logic [1:0]                s_axi_rresp,
  output logic                      s_axi_rlast
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
  logic error, next_error;
  logic [ID_WIDTH-1:0] id, next_id;
  logic [7:0] burst_len, next_burst_len;
  logic last;

  assign addr_error = ((s_axi_araddr >> ADDR_SUBWORD_BITS) != (ADDRESS >> ADDR_SUBWORD_BITS));
  assign size_error = ((1 << s_axi_arsize) != (DATA_WIDTH/8));
  assign burst_error = (s_axi_arburst != BURST_FIXED);

  assign last = (burst_len == 0);
  
  enum {
    IDLE,
    RESP,
    RESP_WAIT_LAST
  } state, next_state;

  always_ff @(posedge clk)
    if (reset) state <= IDLE;
    else       state <= next_state;

  always_comb begin
    next_state = state;
    s_axi_arready = 0;
    input_ready = 0;
    s_axi_rvalid = 0;
    s_axi_rdata = '0;
    s_axi_ruser = '0;
    s_axi_rid = '0;
    s_axi_rresp = '0;
    s_axi_rlast = 0;

    case (state)
      IDLE : begin
        s_axi_arready = 1;
        if (s_axi_arvalid)
          next_state = RESP;
      end

      RESP : begin
        s_axi_rid = id;
        
        s_axi_arready = last;
        s_axi_rlast = last;

        if (~error) begin
          input_ready = s_axi_rready;
          s_axi_rvalid = input_valid;
          s_axi_rdata = input_data;
          s_axi_ruser = input_data_user;
          s_axi_rresp = RSP_OKAY;
        end else begin
          s_axi_rvalid = 1;
          s_axi_rresp = RSP_SLVERR;
        end

        if (last) begin
          case ({(s_axi_rready && s_axi_rvalid), s_axi_arvalid})
            2'b11 : next_state = RESP;
            2'b10 : next_state = IDLE;
            2'b01 : next_state = RESP_WAIT_LAST;
            default;
          endcase
        end
      end

      RESP_WAIT_LAST : begin
        input_ready = s_axi_rready;
        s_axi_rvalid = 1;
        s_axi_rdata = input_data;
        s_axi_ruser = input_data_user;
        s_axi_rid = id;
        s_axi_rresp = error ? RSP_SLVERR : RSP_OKAY;
        s_axi_rlast = 1;

        if (s_axi_rready)
          next_state = RESP;
      end
    endcase
  end

  always_ff @(posedge clk) begin
    case (state)
      IDLE : begin
        if (s_axi_arvalid) begin
          error <= addr_error || size_error || burst_error;
          id <= s_axi_arid;
          burst_len <= s_axi_arlen;
        end
      end

      RESP : begin
        if (last) begin
          if (s_axi_arvalid && s_axi_rready && s_axi_rvalid) begin
            error <= addr_error || size_error || burst_error;
            id <= s_axi_arid;
            burst_len <= s_axi_arlen;
          end else if (s_axi_arvalid) begin
            next_error <= addr_error || size_error || burst_error;
            next_id <= s_axi_arid;
            next_burst_len <= s_axi_arlen;
          end
        end else if (s_axi_rready && s_axi_rvalid) begin
          burst_len <= burst_len - 1;
        end
      end


      RESP_WAIT_LAST : begin
        if (s_axi_rready && s_axi_rvalid) begin
          error <= next_error;
          id <= next_id;
          burst_len <= next_burst_len;
        end
      end
    endcase
  end

endmodule : axi_read_slave
