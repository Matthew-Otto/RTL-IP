// converts a simple ready valid interface into an axi4 lite compliant interface
// write errors will put the interface into an error state
// the interface must be reset to leave this state

module axi_lite_write_master #(ADDR_WIDTH=32, BUS_WIDTH=32) (
  input  logic                      clk,
  input  logic                      reset,
  output logic                      error,

  output logic                      ready,
  input  logic                      valid,
  input  logic [ADDR_WIDTH-1:0]     address,
  input  logic [ADDR_WIDTH-1:0]     data,

  // axi write port
  input  logic                      m_axi_awready,
  output logic                      m_axi_awvalid,
  output logic [ADDR_WIDTH-1:0]     m_axi_awaddr,

  input  logic                      m_axi_wready,
  output logic                      m_axi_wvalid,
  output logic [3:0]                m_axi_wstrb,
  output logic [ADDR_WIDTH-1:0]     m_axi_wdata,
 
  // write resp port
  output logic                      m_axi_bready,
  input  logic                      m_axi_bvalid,
  input  logic [1:0]                m_axi_bresp
);

  localparam
    RSP_OKAY = 2'b00,
    RSP_EXOKAY = 2'b01,
    RSP_SLVERR = 2'b10,
    RSP_DECERR = 2'b11;

  logic pending_write_error;
  
  assign m_axi_awaddr = address;
  assign m_axi_wstrb = '1;
  assign m_axi_wdata = data;

  assign m_axi_bready = 1;

  enum {
    WRITE,
    WRITE_DATA,
    WRITE_ADDR,
    ERROR
  } state, next_state;

  always_ff @(posedge clk)
    if (reset) state <= WRITE;
    else       state <= next_state;

  always_comb begin
    next_state = state;
    ready = 0;
    error = 0;
    m_axi_awvalid = 0;
    m_axi_wvalid = 0;

    case (state)
      WRITE : begin
        if (pending_write_error)
          next_state = ERROR;
        else if (valid) begin
          m_axi_awvalid = 1;
          m_axi_wvalid = 1;
          case ({m_axi_awready, m_axi_wready})
            2'b11 : ready = 1;
            2'b10 : next_state = WRITE_DATA;
            2'b01 : next_state = WRITE_ADDR;
            default;
          endcase
        end
      end

      WRITE_DATA : begin
        m_axi_wvalid = 1;

        if (m_axi_wready) begin
          ready = 1;
          if (pending_write_error)
            next_state = ERROR;
          else
            next_state = WRITE;
        end
      end

      WRITE_ADDR : begin
        m_axi_awvalid = 1;

        if (m_axi_awready) begin
          ready = 1;
          if (pending_write_error)
            next_state = ERROR;
          else
            next_state = WRITE;
        end
      end

      ERROR : begin
        error = 1;
      end
    endcase
  end

  // track errors
  always_ff @(posedge clk) begin
    if (reset)
      pending_write_error <= 0;
    else if (m_axi_bvalid && (m_axi_bresp != RSP_OKAY))
      pending_write_error <= 1;
  end

endmodule : axi_lite_write_master
