module async_fifo #(
  ADDR_WIDTH=6,
  DATA_WIDTH=8
)(
  input  logic                  clk_in,
  input  logic                  clk_out,
  input  logic                  reset,

  output logic                  ready_in,
  input  logic                  valid_in,
  input  logic [DATA_WIDTH-1:0] data_in,
  
  input  logic                  ready_out,
  output logic                  valid_out,
  output logic [DATA_WIDTH-1:0] data_out
);

  logic reset_in, reset_out;
  logic full, empty;
  logic wr_en;

  logic [ADDR_WIDTH-1:0] w_ptr_b, next_w_ptr_b;
  logic [ADDR_WIDTH-1:0] w_ptr_g, next_w_ptr_g;
  logic [ADDR_WIDTH-1:0] r_ptr_g_sync2, r_ptr_g_sync1;
  
  logic [ADDR_WIDTH-1:0] r_addr;
  logic [ADDR_WIDTH-1:0] r_ptr_b, next_r_ptr_b;
  logic [ADDR_WIDTH-1:0] r_ptr_g;
  logic [ADDR_WIDTH-1:0] w_ptr_g_sync2, w_ptr_g_sync1;

  reset_sync write_reset_sync (
    .clk(clk_in),
    .async_reset(reset),
    .sync_reset(reset_in)
  );

  reset_sync read_reset_sync (
    .clk(clk_out),
    .async_reset(reset),
    .sync_reset(reset_out)
  );


  //// write (in_clk) domain
  assign next_w_ptr_b = w_ptr_b + 1;
  assign w_ptr_g = w_ptr_b ^ (w_ptr_b >> 1);
  assign next_w_ptr_g = next_w_ptr_b ^ (next_w_ptr_b >> 1);
  assign full = (next_w_ptr_g == r_ptr_g_sync2);
  assign ready_in = ~full && ~reset_in;
  assign wr_en = ready_in && valid_in && ~reset_in;

  always_ff @(posedge clk_in or posedge reset_in) begin
    if (reset_in)
      w_ptr_b <= 0;
    else if (ready_in && valid_in)
      w_ptr_b <= next_w_ptr_b;
  end

  always_ff @(posedge clk_in or posedge reset_in) begin
    if (reset) {r_ptr_g_sync2, r_ptr_g_sync1} <= 0;
    else       {r_ptr_g_sync2, r_ptr_g_sync1} <= {r_ptr_g_sync1, r_ptr_g};
  end


  //// read (clk_out) domain
  assign next_r_ptr_b = r_ptr_b + 1;
  assign r_ptr_g = r_ptr_b ^ (r_ptr_b >> 1);
  assign empty = (r_ptr_g == w_ptr_g_sync2);
  assign valid_out = ~empty && ~reset_out;

  assign r_addr = (ready_out && valid_out) ? next_r_ptr_b : r_ptr_b;

  always_ff @(posedge clk_out or posedge reset_out) begin
    if (reset_out)
      r_ptr_b <= 0;
    else if (ready_out && valid_out)
      r_ptr_b <= next_r_ptr_b;
  end

  always_ff @(posedge clk_out or posedge reset_out) begin
    if (reset) {w_ptr_g_sync2, w_ptr_g_sync1} <= 0;
    else       {w_ptr_g_sync2, w_ptr_g_sync1} <= {w_ptr_g_sync1, w_ptr_g};
  end


  dual_port_dual_clock_bram #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dual_bram (
    .read_clk(clk_out),
    .write_clk(clk_in),
    .wr_en(wr_en),
    .write_addr(w_ptr_b),
    .write_data(data_in),
    .read_addr(r_addr),
    .read_data(data_out)
  );

endmodule : async_fifo
