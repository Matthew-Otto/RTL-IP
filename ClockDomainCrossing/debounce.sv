// Debounces input from a (active high) physical button. 
// Optionally outputs a single (fast_clk) cycle pulse per button press if STROBE is enabled

module debounce #(parameter CLK_FREQ = 50000000, parameter STROBE = 1) (
  input  logic clk,
  input  logic db_in,
  output logic db_out
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
    q1 <= db_in;
    q2 <= q1;
  end
  assign debounced = q1 & ~q2;

  // strobe button press for a single fast cycle
  generate 
    if (STROBE) begin : strobe
      // asserts db_out for one cycle on rising edge
      always @(posedge clk) begin
        s <= debounced;
        db_out <= debounced & ~s;
      end
    end else begin : nostrobe
      assign db_out = debounced;
    end
  endgenerate

endmodule // debounce
