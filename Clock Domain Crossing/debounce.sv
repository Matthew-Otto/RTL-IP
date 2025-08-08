// Debounces input from a physical button. 
// Optionally outputs a single one-cycle pulse per button press if STROBE is selected

module debounce #(parameter CLK_FREQ, parameter STROBE = 1) (
  input  logic clk,
  input  logic button,
  output logic signal
);

  // find smallest divisor that will generator a period of at least 10ms
  localparam DIVISOR = $clog2(CLK_FREQ / 100);

  logic [DIVISOR-1:0] cnt;
  logic slow_clk;
  logic debounced;
  logic q1, q2, s;

  // divide system clock
  always @(posedge clk) begin
    cnt <= cnt + 1;
  end
  assign slow_clk = cnt[DIVISOR-1];

  // debounce
  always @(posedge slow_clk) begin
    q1 <= button;
    q2 <= q1;
  end
  assign debounced = q1 & ~q2;

  // strobe button press for a single cycle
  generate
    if (STROBE) begin
      // asserts signal for one cycle on rising edge
      always @(posedge clk) begin
        s <= debounced;
        signal <= debounced & ~s;
      end
    end else begin
      assign signal = debounced;
    end
  endgenerate

endmodule // debounce
