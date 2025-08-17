// Speculative FIFO
// Writes can be reverted by asserting the revert signal
// Reverts erase all writes that have occured since last assertion of commit
// Commit "locks in" the writes that have occured so far and will make them visible to the receiver
// Asserting commit and revert in the same cycle will result in a commit
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
        3'b100 : spec_wr_ptr <= spec_wr_ptr + 1;
        3'b01? : spec_wr_ptr <= spec_wr_ptr;
        3'b11? : spec_wr_ptr <= spec_wr_ptr + 1;
        3'b?01 : spec_wr_ptr <= wr_ptr;
        3'b000:;
      endcase
      
      // spec size
      casez ({write, read, commit, revert})
        4'b1000 : spec_size <= spec_size + 1;
        4'b0100 : spec_size <= spec_size - 1;
        4'b1100 : spec_size <= spec_size;
        4'b101? : spec_size <= spec_size + 1;
        4'b011? : spec_size <= spec_size - 1;
        4'b111? : spec_size <= spec_size;
        4'b001? : spec_size <= spec_size;
        4'b?001 : spec_size <= size;
        4'b?101 : spec_size <= size - 1;
        4'b0000:;
      endcase
  
      // wr ptr
      case ({write, commit})
        2'b11 : wr_ptr <= spec_wr_ptr + 1;
        2'b01 : wr_ptr <= spec_wr_ptr;
        default;
      endcase

      // size
      casez ({write, read, commit})
        3'b?10 : size <= size - 1;
        3'b001 : size <= spec_size;
        3'b101 : size <= spec_size + 1;
        3'b111 : size <= spec_size;
        3'b011 : size <= spec_size - 1;
        default;
      endcase
    end
  end

endmodule : spec_fifo
