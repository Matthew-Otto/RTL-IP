// Transmit a pulsed signal between clock domains

/********** potential issues **********/
// if slow_clk period is within 1.5x fast_clk period, slow_output may be asserted for more than one cycle in the slow_clk domain

module cdc_pulse_f2s #(parameter PULSE = 0) (
  // faster domain
  input  logic fast_clk,
  input  logic fast_input,
  // slower domain
  input  logic slow_clk,
  output logic slow_output
);
  // assert on rising edge of fast_input (@posedge fast_clk), deassert on synchronized rising edge of slow_clk
  logic slow_clk_re;
  logic stretch;

  cdc_pulse_s2f(.slow_input(slow_clk & stretch), .fast_clk, .fast_output(slow_clk_re));

  always @(posedge fast_clk) begin
    stretch <= (fast_input | stretch) & ~slow_clk_re;
  end

  // single shot
  generate
    if (PULSE) begin
      logic kill;
      always @(posedge slow_clk) begin
        kill <= stretch;
      end
      assign slow_output = stretch & ~kill;
    end else begin
      assign slow_output = stretch;
    end
  endgenerate

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
