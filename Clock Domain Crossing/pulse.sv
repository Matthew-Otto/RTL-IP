// Transmit a pulsed signal between clock domains

module cdc_pulse_f2s (
  // faster domain
  input  logic fast_clk,
  input  logic fast_input,
  // slower domain
  input  logic slow_clk,
  output logic slow_output
);
  // assert on rising edge of fast_input (@posedge fast_clk), deassert on synchronized rising edge of slow_clk
  logic slow_clk_re;

  cdc_pulse_s2f(.slow_input(slow_clk), .fast_clk, .fast_output(slow_clk_re));

  always @(posedge fast_clk) begin
    slow_output <= (fast_input | slow_output) & ~slow_clk_re;
  end

endmodule // cdc_pulse_f2s


module cdc_pulse_s2f (
  input  logic slow_input,
  input  logic fast_clk,
  output logic fast_output
);

  // flop slow input twice to reduce metastability
  logic metastable, stable;
  // assert synced output pulse for a single fast_clk cycle
  logic kill;

  always @(posedge fast_clk) begin
    metastable <= slow_input;
    stable <= metastable;
    kill <= stable;
  end

  assign fast_output = stable & ~kill;

endmodule // cdc_pulse_s2f
