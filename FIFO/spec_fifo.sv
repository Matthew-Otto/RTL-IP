// Speculative FIFO
// Writes can be reverted by asserting the revert signal
// Reverts erase all writes that have occured since last assertion of commit
// Commit "locks in" the writes that have occured so far and will make them visible to the receiver
// Asserting commit and revert in the same cycle will result in a revert
// Reverts will erase any writes that occur in the same cycle

module spec_fifo #(
  parameter WIDTH = 8,
  parameter DEPTH = 16
) (
  input  logic             clk,
  input  logic             reset,

  // input
  input  logic             commit,
  input  logic             revert,
  output logic             ready_in,
  input  logic             valid_in,
  input  logic [WIDTH-1:0] data_in,

  // output
  input  logic             ready_out,
  output logic             valid_out,
  output logic [WIDTH-1:0] data_out
);

  localparam ADDR_SIZE = $clog2(DEPTH);

  logic full, empty, write, read;
  logic [ADDR_SIZE-1:0] wr_ptr, rd_ptr, spec_wr_ptr;
  logic [ADDR_SIZE-1:0] size, spec_size;
  logic [WIDTH-1:0] buffer [DEPTH-1:0];

  assign full = (spec_size == DEPTH-1);
  assign empty = (size == 0);

  assign ready_in = ~full;
  assign valid_out = ~empty;
  assign data_out = buffer[rd_ptr];

  assign write = valid_in && ~full;
  assign read = ready_out && ~empty;

  always_ff @(posedge clk) begin
    if (reset) begin
      size <= 0;
      spec_size <= 0;
      wr_ptr <= 0;
      spec_wr_ptr <= 0;
      rd_ptr <= 0;
    end else begin
      if (write)
        buffer[spec_wr_ptr] <= data_in;

      if (read)
        rd_ptr <= rd_ptr + 1;

      // spec wr ptr
      casez ({write, commit, revert})
        3'b??1 : spec_wr_ptr <= wr_ptr;
        3'b1?0 : spec_wr_ptr <= spec_wr_ptr + 1;
        3'b010:;
        3'b000:;
      endcase
      
      // spec size
      casez ({write, read, commit, revert})
        4'b?0?1 : spec_size <= size;
        4'b?1?1 : spec_size <= size - 1;
        4'b10?0 : spec_size <= spec_size + 1;
        4'b01?0 : spec_size <= spec_size - 1;
        4'b11?0 : spec_size <= spec_size;
        4'b00?0:;
      endcase
  
      // wr ptr
      case ({write, commit, revert})
        3'b110 : wr_ptr <= spec_wr_ptr + 1;
        3'b010 : wr_ptr <= spec_wr_ptr;
        default;
      endcase

      // size
      casez ({write, read, commit, revert})
        4'b0010 : size <= spec_size;
        4'b1010 : size <= spec_size + 1;
        4'b1110 : size <= spec_size;
        4'b0110 : size <= spec_size - 1;
        4'b1000 : size <= size;
        4'b?100 : size <= size - 1;
        4'b?1?1 : size <= size - 1;
        4'b?0?1 : size <= size;
        4'b0000:;
      endcase
    end
  end

endmodule : spec_fifo
