// TODO description
// writes can be reverted by asserting the revert signal
// reverts erase all writes that have occured since last assertion of commit
// commit "locks in" the writes that have occured so far and will make them visible to the receiver

module spec_fifo #(parameter WIDTH, parameter DEPTH) (
  input  logic clk,
  input  logic reset,

  // input
  input  logic commit,
  input  logic revert,
  output logic ready_in,
  input  logic valid_in,
  input  logic [WIDTH-1:0] data_in,

  // output
  input  logic ready_out,
  output logic valid_out,
  output logic [WIDTH-1:0] data_out
);

  localparam ADDR_SIZE = $clog2(DEPTH);

  logic full, empty, write, read;
  logic [ADDR_SIZE-1:0] wr_ptr, spec_wr_ptr, rd_ptr;
  logic [WIDTH-1:0] buffer [DEPTH-1:0];

  assign full = ((spec_wr_ptr + 1) % DEPTH) == rd_ptr;
  assign empty = (wr_ptr == rd_ptr);

  assign ready_in = ~full;
  assign valid_out = ~empty;
  assign data_out = buffer[rd_ptr];

  assign write = valid_in && ~full;
  assign read = ready_out && ~empty;

  always_ff @(posedge clk) begin
    if (reset) begin
      wr_ptr <= 0;
      spec_wr_ptr <= 0;
      rd_ptr <= 0;
    end else begin
      if (write) begin
        buffer[spec_wr_ptr] <= data_in;
        spec_wr_ptr <= spec_wr_ptr + 1;
      end

      if (read) begin
        rd_ptr <= rd_ptr + 1;
      end

      if (commit)
        wr_ptr <= write ? spec_wr_ptr + 1 : spec_wr_ptr;
      else if (revert)
        spec_wr_ptr <= wr_ptr;
    end
  end

endmodule // fifo
