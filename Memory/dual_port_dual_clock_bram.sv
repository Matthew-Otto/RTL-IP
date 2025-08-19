// Simple dual-port bram with separate read and write clocks

module dual_port_dual_clock_bram #(
  ADDR_WIDTH=6,
  DATA_WIDTH=8
)(
  input  logic                  read_clk,
  input  logic                  write_clk,
  input  logic                  wr_en,
  input  logic [ADDR_WIDTH-1:0] write_addr,
  input  logic [DATA_WIDTH-1:0] write_data,
  input  logic [ADDR_WIDTH-1:0] read_addr,
  output logic [DATA_WIDTH-1:0] read_data
);

  logic [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];

  always_ff @(posedge write_clk) begin
    if (wr_en)
      ram[write_addr] <= write_data;
  end

  always_ff @(posedge read_clk) begin
      read_data <= ram[read_addr];
  end

endmodule : dual_port_dual_clock_bram
