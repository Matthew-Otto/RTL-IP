// two stage sync

module reset_sync (
  input  logic clk,
  input  logic async_reset,
  output logic sync_reset
);

  logic [1:0] sync;

  always @(posedge clk or posedge async_reset) begin
    if (async_reset)
      sync <= 2'b11;
    else
      sync <= {sync[0], async_reset};
  end

  assign sync_reset = async_reset || sync[1];

endmodule : reset_sync
