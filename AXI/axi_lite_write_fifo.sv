module axi_lite_write_fifo #(
  ADDRESS = 'h0000_0000,
  ADDR_WIDTH = 32,
  BUS_WIDTH = 32,
  DEPTH = 8
) (
  input  logic                      clk,
  input  logic                      reset,

  // input
  output logic                      s_axi_awready,
  input  logic                      s_axi_awvalid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr,
  input  logic [2:0]                s_axi_awprot,
  
  output logic                      s_axi_wready,
  input  logic                      s_axi_wvalid,
  input  logic [3:0]                s_axi_wstrb,
  input  logic [BUS_WIDTH-1:0]      s_axi_wdata,
  
  input  logic                      s_axi_bready,
  output logic                      s_axi_bvalid,
  output logic [1:0]                s_axi_bresp,

  // output
  input  logic                      ready_out,
  output logic                      valid_out,
  output logic [BUS_WIDTH-1:0]      data_out
);

  localparam WORD_OFFSET = BUS_WIDTH / 8;
  localparam ADDR_ALIGN = $clog2(WORD_OFFSET);


  //////////////////////////////////////
  //// FIFO ////////////////////////////
  //////////////////////////////////////
  localparam ADDR_SIZE = $clog2(DEPTH);

  logic valid_in;
  logic [BUS_WIDTH-1:0] data_in;

  logic full, empty, write, read;
  logic [ADDR_SIZE-1:0] wr_ptr, rd_ptr, size;
  logic [BUS_WIDTH-1:0] buffer [DEPTH-1:0];

  assign full = (size == DEPTH-1);
  assign empty = (size == 0);

  assign valid_out = ~empty;
  assign data_out = buffer[rd_ptr];

  assign write = valid_in && ~full;
  assign read = ready_out && ~empty;

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

  logic [ADDR_WIDTH-1:0] addr_b;
  logic [3:0]            data_strb_b;
  logic [31:0]           data_b;
  logic [1:0]            resp_b;

  enum {
    READY,
    VALID_ADDR,
    VALID_DATA,
    WRITE,
    READY_PEND_RSP,
    VALID_ADDR_PEND_RSP,
    VALID_DATA_PEND_RSP,
    WRITE_PEND_RSP
  } state, next_state;



  always_ff @(posedge clk) begin
    if (reset) state <= READY;
    else       state <= next_state;

    if (s_axi_awready && s_axi_awvalid)
      addr_b <= s_axi_awaddr;

    if (s_axi_wready && s_axi_wvalid) begin
      data_b <= s_axi_wdata;
      data_strb_b <= s_axi_wstrb;
    end

    if (state == WRITE)
      resp_b <= s_axi_bresp;
  end

  always_comb begin
    next_state = state;
    s_axi_awready = 0;
    s_axi_wready = 0;
    s_axi_bvalid = 0;
    s_axi_bresp = RSP_OKAY;
    valid_in = 0;

    case (state)
      // buffer is empty, no responses pending
      READY : begin
        s_axi_awready = ~full;
        s_axi_wready = ~full;

        case ({~full, s_axi_awvalid, s_axi_wvalid})
          3'b111 : next_state = WRITE;
          3'b110 : next_state = VALID_ADDR;
          3'b101 : next_state = VALID_DATA;
          default: next_state = state;
        endcase
      end

      // buffered address, need data
      VALID_ADDR : begin
        s_axi_wready = 1;
        if (s_axi_wvalid)
          next_state = WRITE;
      end

      // buffered data, need address
      VALID_DATA : begin
        s_axi_awready = 1;
        if (s_axi_awvalid)
          next_state = WRITE;
      end

      // addr + data are valid, write to control register, send response
      WRITE : begin
        s_axi_bvalid = 1;
        
        // decode valid addresses
        if (addr_b[ADDR_WIDTH-1:ADDR_ALIGN] == ADDRESS>>ADDR_ALIGN) begin
          valid_in = 1;
          s_axi_bresp = RSP_OKAY;
        end else begin
          s_axi_bresp = RSP_SLVERR;
        end

        s_axi_awready = 1;
        s_axi_wready = 1;

        case ({s_axi_awvalid, s_axi_wvalid, s_axi_bready})
          3'b001 : next_state = READY;
          3'b101 : next_state = VALID_ADDR;
          3'b011 : next_state = VALID_DATA;
          3'b111 : next_state = WRITE;
          3'b000 : next_state = READY_PEND_RSP;
          3'b100 : next_state = VALID_ADDR_PEND_RSP;
          3'b010 : next_state = VALID_DATA_PEND_RSP;
          3'b110 : next_state = WRITE_PEND_RSP;
        endcase
      end

      // buffer empty but pending response
      READY_PEND_RSP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = resp_b;

        s_axi_awready = 1;
        s_axi_wready = 1;
        case ({s_axi_awvalid, s_axi_wvalid, s_axi_bready})
          3'b111 : next_state = WRITE;
          3'b101 : next_state = VALID_ADDR;
          3'b011 : next_state = VALID_DATA;
          3'b001 : next_state = READY;
          3'b110 : next_state = WRITE_PEND_RSP;
          3'b100 : next_state = VALID_ADDR_PEND_RSP;
          3'b010 : next_state = VALID_DATA_PEND_RSP;
          3'b000 : next_state = READY_PEND_RSP;
        endcase
      end

      // buffered addr but previous response pending
      VALID_ADDR_PEND_RSP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = resp_b;

        s_axi_wready = 1;
        case ({s_axi_wvalid, s_axi_bready})
          2'b10 : next_state = WRITE_PEND_RSP;
          2'b01 : next_state = VALID_ADDR;
          2'b11 : next_state = WRITE;
          2'b00 : next_state = VALID_ADDR_PEND_RSP;
        endcase
      end

      // buffered data but previous response pending
      VALID_DATA_PEND_RSP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = resp_b;

        s_axi_awready = 1;
        case ({s_axi_awvalid, s_axi_bready})
          2'b10 : next_state = WRITE_PEND_RSP;
          2'b01 : next_state = VALID_DATA;
          2'b11 : next_state = WRITE;
          2'b00 : next_state = VALID_DATA_PEND_RSP;
        endcase
      end

      // valid buffer but previous response pending
      WRITE_PEND_RSP : begin
        s_axi_bvalid = 1;
        s_axi_bresp = resp_b;
        if (s_axi_bready)
          next_state = WRITE;
      end
    endcase

    for (int i = 0; i < BUS_WIDTH/8; i++)
      data_in[i*8+:8] = data_strb_b[i] ? data_b[i*8+:8] : '0;
  end

endmodule : axi_lite_write_fifo
