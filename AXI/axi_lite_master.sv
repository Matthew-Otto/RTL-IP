// Translates AXI lite interface to simple core interface

module axi_lite_master #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
) (
    input  logic                      clk,
    input  logic                      reset,

    input  logic                      core_write_i,
    input  logic                      core_read_i,
    input  logic [AXI_ADDR_WIDTH-1:0] core_addr_i,
    input  logic [AXI_DATA_WIDTH-1:0] core_wdata_i,
    
    output logic                      core_rvalid_o,
    output logic [AXI_DATA_WIDTH-1:0] core_rdata_o,
    output logic                      cmd_error_o,  // 1 = Slave returned SLVERR/DECERR
    
    output logic                      core_axi_cmd_rdy_o,

    axi_lite_if.master                m_axi
);

    assign m_axi.awaddr = core_addr_i;
    assign m_axi.araddr = core_addr_i;

    assign m_axi.wdata = core_wdata_i;
    assign m_axi.wstrb = '1;
    assign m_axi.bready = 1'b1;

    assign m_axi.rready = 1'b1;

    assign m_axi.wvalid = core_write_i;
    assign m_axi.awvalid = core_write_i;
    
    assign m_axi.arvalid = core_read_i;

    assign core_rvalid_o = m_axi.rvalid;
    assign core_rdata_o = m_axi.rdata;
    assign cmd_error_o = (m_axi.rresp != 0);

    assign core_axi_cmd_rdy_o = m_axi.awready & m_axi.wready & m_axi.rready;

endmodule : axi_lite_master
