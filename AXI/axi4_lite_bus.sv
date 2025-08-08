// basic AXI4_lite bus
// allows a parameterizable number of master and slave ports
// automatic priority arbitration; lower id master has higher priority

module axi4_lite_bus #(
  parameter NUM_MASTERS = 1, 
  parameter NUM_SLAVES = 1, 
  parameter ADDR_WIDTH = 16, 
  parameter DATA_WIDTH = 16,
  parameter logic [ADDR_WIDTH*NUM_SLAVES-1:0] BASE_ADDRS = '0,
  parameter logic [ADDR_WIDTH*NUM_SLAVES-1:0] ADDR_MASKS = '0
)(
  input  logic clk,
  input  logic reset,

  // master port(s)
  output logic [NUM_MASTERS-1:0]                      m_axi_awready,
  input  logic [NUM_MASTERS-1:0]                      m_axi_awvalid,
  input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]      m_axi_awaddr,
  output logic [NUM_MASTERS-1:0]                      m_axi_wready,
  input  logic [NUM_MASTERS-1:0]                      m_axi_wvalid,
  input  logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]      m_axi_wdata,
  input  logic [NUM_MASTERS-1:0][(DATA_WIDTH/8)-1:0]  m_axi_wstrb,
  output logic [NUM_MASTERS-1:0]                      m_axi_bvalid,
  input  logic [NUM_MASTERS-1:0]                      m_axi_bready,
  output logic [NUM_MASTERS-1:0]                      m_axi_bresp,
  output logic [NUM_MASTERS-1:0]                      m_axi_arready,
  input  logic [NUM_MASTERS-1:0]                      m_axi_arvalid,
  input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]      m_axi_araddr,
  input  logic [NUM_MASTERS-1:0]                      m_axi_rready,
  output logic [NUM_MASTERS-1:0]                      m_axi_rvalid,
  output logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]      m_axi_rdata,
  output logic [NUM_MASTERS-1:0]                      m_axi_rresp,

  // slave port
  input  logic [NUM_SLAVES-1:0]                       s_axi_awready,
  output logic [NUM_SLAVES-1:0]                       s_axi_awvalid,
  output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]       s_axi_awaddr,
  input  logic [NUM_SLAVES-1:0]                       s_axi_wready,
  output logic [NUM_SLAVES-1:0]                       s_axi_wvalid,
  output logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]       s_axi_wdata,
  output logic [NUM_SLAVES-1:0][(DATA_WIDTH/8)-1:0]   s_axi_wstrb,
  input  logic [NUM_SLAVES-1:0]                       s_axi_bvalid,
  output logic [NUM_SLAVES-1:0]                       s_axi_bready,
  input  logic [NUM_SLAVES-1:0]                       s_axi_bresp,
  input  logic [NUM_SLAVES-1:0]                       s_axi_arready,
  output logic [NUM_SLAVES-1:0]                       s_axi_arvalid,
  output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]       s_axi_araddr,
  output logic [NUM_SLAVES-1:0]                       s_axi_rready,
  input  logic [NUM_SLAVES-1:0]                       s_axi_rvalid,
  input  logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]       s_axi_rdata,
  input  logic [NUM_SLAVES-1:0]                       s_axi_rresp
);
  localparam int MASTER_SEL_WIDTH = (NUM_MASTERS > 1) ? $clog2(NUM_MASTERS) : 1;
  localparam int SLAVE_SEL_WIDTH = (NUM_SLAVES > 1) ? $clog2(NUM_SLAVES) : 1;

  logic [NUM_MASTERS-1:0]                     d_m_axi_awready;
  logic [NUM_MASTERS-1:0]                     d_m_axi_awvalid;
  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]     d_m_axi_awaddr;
  logic [NUM_MASTERS-1:0]                     d_m_axi_wready;
  logic [NUM_MASTERS-1:0]                     d_m_axi_wvalid;
  logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]     d_m_axi_wdata;
  logic [NUM_MASTERS-1:0][(DATA_WIDTH/8)-1:0] d_m_axi_wstrb;
  logic [NUM_MASTERS-1:0]                     d_m_axi_bvalid;
  logic [NUM_MASTERS-1:0]                     d_m_axi_bready;
  logic [NUM_MASTERS-1:0]                     d_m_axi_bresp;
  logic [NUM_MASTERS-1:0]                     d_m_axi_arready;
  logic [NUM_MASTERS-1:0]                     d_m_axi_arvalid;
  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]     d_m_axi_araddr;
  logic [NUM_MASTERS-1:0]                     d_m_axi_rready;
  logic [NUM_MASTERS-1:0]                     d_m_axi_rvalid;
  logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]     d_m_axi_rdata;
  logic [NUM_MASTERS-1:0]                     d_m_axi_rresp;

  logic [SLAVE_SEL_WIDTH-1:0] target_slave_write, target_slave_read;
  logic write_match, read_match;

  logic [MASTER_SEL_WIDTH-1:0] master_sel;
  logic transaction_in_progress;

  // select master based on arbiter
  always_comb begin
    // input
    d_m_axi_awvalid = m_axi_awvalid[master_sel];
    d_m_axi_awaddr = m_axi_awaddr[master_sel];
    d_m_axi_wvalid = m_axi_wvalid[master_sel];
    d_m_axi_wdata = m_axi_wdata[master_sel];
    d_m_axi_wstrb = m_axi_wstrb[master_sel];
    d_m_axi_bready = m_axi_bready[master_sel];
    d_m_axi_arvalid = m_axi_arvalid[master_sel];
    d_m_axi_araddr = m_axi_araddr[master_sel];
    d_m_axi_rready = m_axi_rready[master_sel];
    //output
    for (int i = 0; i < NUM_MASTERS; ++i) begin
      m_axi_awready[i] = (i == master_sel) ? d_m_axi_awready : '0;
      m_axi_wready[i] = (i == master_sel) ? d_m_axi_wready : '0;
      m_axi_bvalid[i] = (i == master_sel) ? d_m_axi_bvalid : '0;
      m_axi_bresp[i] = (i == master_sel) ? d_m_axi_bresp : '0;
      m_axi_arready[i] = (i == master_sel) ? d_m_axi_arready : '0;
      m_axi_rvalid[i] = (i == master_sel) ? d_m_axi_rvalid : '0;
      m_axi_rdata[i] = (i == master_sel) ? d_m_axi_rdata : '0;
      m_axi_rresp[i] = (i == master_sel) ? d_m_axi_rresp : '0;
    end
  end

  // address decode
  always_comb begin
    read_match = 0;
    write_match = 0;
    target_slave_read = 'x;
    target_slave_write = 'x;

    for (int i = 0; i < NUM_SLAVES; i++) begin
      if ((d_m_axi_araddr & ADDR_MASKS[ADDR_WIDTH*i+:ADDR_WIDTH]) == BASE_ADDRS[ADDR_WIDTH*i+:ADDR_WIDTH]) begin
        target_slave_read = i;
        read_match = 1;
      end
      if ((d_m_axi_awaddr & ADDR_MASKS[ADDR_WIDTH*i+:ADDR_WIDTH]) == BASE_ADDRS[ADDR_WIDTH*i+:ADDR_WIDTH]) begin
        target_slave_write = i;
        write_match = 1;
      end
    end
  end

  // slave select
  always_comb begin
    // output
    for (int i = 0; i < NUM_SLAVES; i++) begin
      s_axi_awvalid[i] = (write_match && (i == target_slave_write)) ? d_m_axi_awvalid : '0;
      s_axi_awaddr[i] = (write_match && (i == target_slave_write)) ? d_m_axi_awaddr : '0;
      s_axi_wvalid[i] = (write_match && (i == target_slave_write)) ? d_m_axi_wvalid : '0;
      s_axi_wdata[i] = (write_match && (i == target_slave_write)) ? d_m_axi_wdata : '0;
      s_axi_wstrb[i] = (write_match && (i == target_slave_write)) ? d_m_axi_wstrb : '0;
      s_axi_bready[i] = (write_match && (i == target_slave_write)) ? d_m_axi_bready : '0;
      s_axi_arvalid[i] = (read_match && (i == target_slave_read)) ? d_m_axi_arvalid : '0;
      s_axi_araddr[i] = (read_match && (i == target_slave_read)) ? d_m_axi_araddr : '0;
      s_axi_rready[i] = (read_match && (i == target_slave_read)) ? d_m_axi_rready : '0;
    end
    // input
    d_m_axi_awready = s_axi_awready[target_slave_write];
    d_m_axi_wready = s_axi_wready[target_slave_write];
    d_m_axi_bvalid = s_axi_bvalid[target_slave_write];
    d_m_axi_bresp = s_axi_bresp[target_slave_write];
    d_m_axi_arready = s_axi_arready[target_slave_read];
    d_m_axi_rvalid = s_axi_rvalid[target_slave_read];
    d_m_axi_rdata = s_axi_rdata[target_slave_read];
    d_m_axi_rresp = s_axi_rresp[target_slave_read];
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      master_sel <= 'x;
      transaction_in_progress <= 0;
    end else begin
      for (int i = NUM_MASTERS-1; i > -1; i--) begin
        if (~transaction_in_progress && (m_axi_awvalid[i] || m_axi_wvalid[i] || m_axi_arvalid[i])) begin
          master_sel <= i;
          transaction_in_progress <= 1;
        end else if ((d_m_axi_bready && d_m_axi_bvalid) || (d_m_axi_rready && d_m_axi_rvalid)) begin
          transaction_in_progress <= 0;
        end
      end
    end
  end

endmodule // axi4_lite_bus
