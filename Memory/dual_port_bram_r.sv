// Simple dual-port bram with reset function

module dual_port_bram_r #(
  ADDR_WIDTH=8,
  DATA_WIDTH=32
)(
  input  logic                  clk,
  input  logic                  reset,
  output logic                  reset_done,
  input  logic                  wr_en,
  input  logic [ADDR_WIDTH-1:0] write_addr,
  input  logic [DATA_WIDTH-1:0] write_data,
  input  logic [ADDR_WIDTH-1:0] read_addr,
  output logic [DATA_WIDTH-1:0] read_data
);

  localparam MEM_DEPTH = 1 << ADDR_WIDTH;

  logic [ADDR_WIDTH:0]   reset_counter;
  logic                  wr_en_mux;
  logic [ADDR_WIDTH-1:0] wr_addr_mux;
  logic [DATA_WIDTH-1:0] wr_data_mux;

  assign reset_done = (reset_counter == MEM_DEPTH);

  always_ff @(posedge clk) begin
    if (reset)
      reset_counter <= 0;
    else if (~reset_done)
      reset_counter <= reset_counter + 1;
  end

  assign wr_en_mux = ~reset_done ? 1 : wr_en;
  assign wr_addr_mux = ~reset_done ? reset_counter[ADDR_WIDTH-1:0] : write_addr;
  assign wr_data_mux = ~reset_done ? '0 : write_data;


  dual_port_bram #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) bram (
    .clk,
    .wr_en(wr_en_mux),
    .write_addr(wr_addr_mux),
    .write_data(wr_data_mux),
    .read_addr,
    .read_data
  );

endmodule : dual_port_bram_r
