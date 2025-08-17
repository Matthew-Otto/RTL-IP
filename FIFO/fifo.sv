module fifo #(
  parameter WIDTH = 8, 
  parameter DEPTH = 8, 
  parameter ALMOST_FULL_THRESHOLD = 0,
  parameter ALMOST_EMPTY_THRESHOLD = 0
) (
  input  logic clk,
  input  logic reset,

  // input
  output logic ready_in,
  input  logic valid_in,
  input  logic [WIDTH-1:0] data_in,

  // output
  input  logic ready_out,
  output logic valid_out,
  output logic [WIDTH-1:0] data_out,

  output logic almost_full,
  output logic almost_empty
);

  localparam ADDR_SIZE = $clog2(DEPTH);

  logic full, empty, write, read;
  logic [ADDR_SIZE-1:0] wr_ptr, rd_ptr, size;
  logic [WIDTH-1:0] buffer [DEPTH-1:0];

  generate
    if (ALMOST_FULL_THRESHOLD > 0) begin : gen_almost_full
      assign almost_full = (size > DEPTH-(2+ALMOST_FULL_THRESHOLD));
    end

    if (ALMOST_EMPTY_THRESHOLD > 0) begin : gen_almost_empty
      assign almost_empty = (size < (ALMOST_EMPTY_THRESHOLD+1));
    end
  endgenerate

  assign full = (size == DEPTH-1);
  assign empty = (size == 0);

  assign ready_in = ~full;
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

endmodule // fifo
