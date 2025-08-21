module one_bit_synchro (
  input  logic clk,
  input  logic reset,

  input  logic data_in,
  output logic data_out
);

  logic sync2, sync1;

  always_ff @(posedge clk or posedge reset)
    if (reset) {sync2,sync1} <= 0;
    else       {sync2,sync1} <= {sync1, data_in};

  assign data_out = sync2;

endmodule : one_bit_synchro
