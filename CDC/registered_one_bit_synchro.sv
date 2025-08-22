module registered_one_bit_synchro (
  input  logic in_clk,
  input  logic out_clk,

  input  logic data_in,
  output logic data_out
);

  logic sync2, sync1, data_in_r;

  always_ff @(posedge in_clk) begin
    data_in_r <= data_in;
  end

  always_ff @(posedge out_clk) begin
    sync1 <= data_in_r;
    sync2 <= sync1;
  end

  assign data_out = sync2;

endmodule : registered_one_bit_synchro
