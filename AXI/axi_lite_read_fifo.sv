module axi_lite_read_fifo #(
  ADDRESS = 'h0000_0000,
  ADDR_WIDTH = 32,
  BUS_WIDTH = 32,
  DEPTH = 8
) (
  input  logic                      clk,
  input  logic                      reset,

  // input
  output logic                      ready_in,
  input  logic                      valid_in,
  input  logic [BUS_WIDTH-1:0]      data_in,

  // output
  output logic                      s_axi_arready,
  input  logic                      s_axi_arvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_araddr,

  input  logic                      s_axi_rready,
  output logic                      s_axi_rvalid,
  output logic [BUS_WIDTH-1:0]      s_axi_rdata,
  output logic [1:0]                s_axi_rresp
);

  localparam WORD_OFFSET = BUS_WIDTH / 8;
  localparam ADDR_ALIGN = $clog2(WORD_OFFSET);


  //////////////////////////////////////
  //// FIFO ////////////////////////////
  //////////////////////////////////////
  localparam ADDR_SIZE = $clog2(DEPTH);

  logic full, empty, write, read;
  logic [ADDR_SIZE-1:0] wr_ptr, rd_ptr, size;
  logic [BUS_WIDTH-1:0] buffer [DEPTH-1:0];

  assign full = (size == DEPTH-1);
  assign empty = (size == 0);

  assign ready_in = ~full;

  assign write = valid_in && ~full;

  always_ff @(posedge clk) begin
    if (reset) begin
      size <= 0;
      wr_ptr <= 0;
      rd_ptr <= 0;
    end else begin
      if (write) begin
        buffer[wr_ptr] <= data_in;
        wr_ptr <= wr_ptr + 1;
      end

      if (read) begin
        rd_ptr <= rd_ptr + 1;
      end

      case ({write, read})
        2'b10 : size <= size + 1;
        2'b01 : size <= size - 1;
        default;
      endcase
    end
  end


  //////////////////////////////////////
  //// AXI-Lite slave interface ////////
  //////////////////////////////////////
  localparam
    RSP_OKAY = 2'b00,
    RSP_EXOKAY = 2'b01,
    RSP_SLVERR = 2'b10,
    RSP_DECERR = 2'b11;

  enum {
    READY,
    READ,
    BADADDR
  } state, next_state;

  always_ff @(posedge clk)
    if (reset) state <= READY;
    else       state <= next_state;

  always_comb begin
    next_state = state;
    s_axi_arready = 0;
    s_axi_rvalid = 0;
    s_axi_rdata = 0;
    s_axi_rresp = RSP_OKAY;

    case (state)
      READY : begin
        s_axi_arready = ~empty;

        if (s_axi_arvalid)
          if (s_axi_araddr[ADDR_WIDTH-1:ADDR_ALIGN] == ADDRESS>>ADDR_ALIGN)
            next_state = READ;
          else
            next_state = BADADDR;
      end

      READ : begin
        s_axi_rvalid = 1;
        s_axi_rdata = buffer[rd_ptr];
        read = s_axi_rready;
        
        if (s_axi_rready)
          next_state = READY;
      end

      BADADDR : begin
        s_axi_rvalid = 1;
        s_axi_rresp = RSP_SLVERR;

        if (s_axi_rready)
          next_state = READY;
      end
    endcase
  end

endmodule : axi_lite_read_fifo
