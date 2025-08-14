// Reset synchronizer

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
      sync <= {sync[0], 1'b0};
  end

  assign sync_reset = sync[1];

endmodule : reset_sync
