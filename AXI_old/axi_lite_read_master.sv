// converts a simple ready valid interface into an axi4 lite compliant interface
// read errors will put the interface into an error state
// the interface must be reset to leave this state

module axi_lite_read_master #(ADDR_WIDTH=32) (
  input  logic                      clk,
  input  logic                      reset,
  output logic                      error,

  output logic                      addr_ready,
  input  logic                      addr_valid,
  input  logic [ADDR_WIDTH-1:0]     addr,

  input  logic                      data_ready,
  output logic                      data_valid,
  output logic [31:0]               data,

  // axi read port
  input  logic                      m_axi_arready,
  output logic                      m_axi_arvalid,
  output logic [ADDR_WIDTH-1:0]     m_axi_araddr,

  // read resp port
  output logic                      m_axi_rready,
  input  logic                      m_axi_rvalid,
  input  logic [31:0]               m_axi_rdata,
  input  logic [1:0]                m_axi_rresp
);

  localparam
    RSP_OKAY = 2'b00,
    RSP_EXOKAY = 2'b01,
    RSP_SLVERR = 2'b10,
    RSP_DECERR = 2'b11;

  logic error_latch;

  assign error = (m_axi_rvalid && |m_axi_rresp) || error_latch;

  always_ff @(posedge clk)
    if (reset)
      error_latch <= 0;
    else
      error_latch <= error;

  assign addr_ready = m_axi_arready && ~error;
  assign m_axi_arvalid = addr_valid && ~error;
  assign m_axi_araddr = addr;

  assign m_axi_rready = data_ready;
  assign data_valid = m_axi_rvalid;
  assign data = m_axi_rdata;

endmodule : axi_lite_read_master
