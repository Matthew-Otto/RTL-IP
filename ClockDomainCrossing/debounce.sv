// Debounces input from a (active high) physical button. 
// Optionally outputs a single (fast_clk) cycle pulse per button press if STROBE is enabled

module debounce #(parameter CLK_FREQ = 50000000) (
  input  logic clk,
  input  logic db_in,
  output logic db_out
);

  // find smallest divisor that will generate a period of at least 10ms
  localparam DIVISOR = $clog2(CLK_FREQ / 100);

  logic [DIVISOR-1:0] cnt;
  logic q1, q2;
  logic db_in_rising_edge;

  assign db_in_rising_edge = q1 && ~q2;

  always @(posedge clk or posedge db_in) begin
    q1 <= db_in;
    q2 <= q1;

    if (|cnt || db_in_rising_edge)
      cnt <= cnt + 1;
  end

  assign db_out = &cnt && db_in;

endmodule : debounce
