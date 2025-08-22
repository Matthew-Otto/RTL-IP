module one_bit_synchro (
  input  logic clk,

  input  logic data_in,
  output logic data_out
);

  logic sync2, sync1;

  always_ff @(posedge clk) begin
    sync1 <= data_in;
    sync2 <= sync1;
  end

  assign data_out = sync2;

endmodule : one_bit_synchro
