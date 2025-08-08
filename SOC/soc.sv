// top level wrapper module for various SOC configurations

module soc #(CLK_RATE=50_000_000, BAUD_RATE=115200) (
  input  logic clk,
  input  logic reset,

  input  logic urx,
  output logic utx
);

  localparam ADDR_WIDTH = 32;


  // DMA Control Bus
  logic                  dma_arready;
  logic                  dma_arvalid;
  logic [ADDR_WIDTH-1:0] dma_araddr;
  logic                  dma_rready;
  logic                  dma_rvalid;
  logic [31:0]           dma_rdata;
  logic [1:0]            dma_rresp;
  logic                  dma_awready;
  logic                  dma_awvalid;
  logic [ADDR_WIDTH-1:0] dma_awaddr;
  logic                  dma_wready;
  logic                  dma_wvalid;
  logic [3:0]            dma_wstrb;
  logic [31:0]           dma_wdata;
  logic                  dma_bready;
  logic                  dma_bvalid;
  logic                  dma_bresp;


  serial_interface #(.CLK_RATE, .BAUD_RATE) serial_interface_i (
    .clk,
    .reset,
    // UART
    .urx,
    .utx,
    // AXI Interface
    // input (read)
    .m_axi_arready(dma_arready),
    .m_axi_arvalid(dma_arvalid),
    .m_axi_araddr(dma_araddr),
    .m_axi_rready(dma_rready),
    .m_axi_rvalid(dma_rvalid),
    .m_axi_rdata(dma_rdata),
    .m_axi_rresp(dma_rresp),
    // output (write)
    .m_axi_awready(dma_awready),
    .m_axi_awvalid(dma_awvalid),
    .m_axi_awaddr(dma_awaddr),
    .m_axi_wready(dma_wready),
    .m_axi_wvalid(dma_wvalid),
    .m_axi_wstrb(dma_wstrb),
    .m_axi_wdata(dma_wdata),
    .m_axi_bready(dma_bready),
    .m_axi_bvalid(dma_bvalid),
    .m_axi_bresp(dma_bresp)
  );

  dma #(ADDR_WIDTH) dma_i (
    .clk,
    .reset,
    // control register write port (slave)
    .s_axi_awready(dma_awready),
    .s_axi_awvalid(dma_awvalid),
    .s_axi_awaddr(dma_awaddr),
    .s_axi_awprot(),
    .s_axi_wready(dma_wready),
    .s_axi_wvalid(dma_wvalid),
    .s_axi_wstrb(dma_wstrb),
    .s_axi_wdata(dma_wdata),
    .s_axi_bready(dma_bready),
    .s_axi_bvalid(dma_bvalid),
    .s_axi_bresp(dma_bresp),
    // control register read port (slave)
    .s_axi_arready(dma_arready),
    .s_axi_arvalid(dma_arvalid),
    .s_axi_araddr(dma_araddr),
    .s_axi_rready(dma_rready),
    .s_axi_rvalid(dma_rvalid),
    .s_axi_rdata(dma_rdata),
    .s_axi_rresp(dma_rresp),
    // input (read) port (master)
    .m_axi_arready(),
    .m_axi_arvalid(),
    .m_axi_araddr(),
    .m_axi_rready(),
    .m_axi_rvalid(),
    .m_axi_rdata(),
    .m_axi_rresp(),
    // output (write) port (master)
    .m_axi_awready(),
    .m_axi_awvalid(),
    .m_axi_awaddr(),
    .m_axi_wready(),
    .m_axi_wvalid(),
    .m_axi_wstrb(),
    .m_axi_wdata(),
    .m_axi_bready(),
    .m_axi_bvalid(),
    .m_axi_bresp()
  );

endmodule : soc
