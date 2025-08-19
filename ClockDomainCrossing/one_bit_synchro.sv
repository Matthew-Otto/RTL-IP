module one_bit_synchro (
  input  logic clk,
  input  logic reset,

  input  logic data_in,
  output logic data_out
);

  logic sync;

  always_ff @(posedge clk or posedge reset)
    if (reset) {data_out,sync} <= 0;
    else       {data_out,sync} <= {sync, data_in};

endmodule : one_bit_synchro
