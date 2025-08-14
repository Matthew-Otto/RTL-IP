// Holds a reset signal for the first few cycles after initialization

module init_rst #(DELAY = 16) (
  input  logic clk,
  output logic rst
);

  logic [DELAY-1:0] shift_reg;
  initial shift_reg = 0;

  assign rst = ~shift_reg[DELAY-1];

  always @(posedge clk) begin
    shift_reg <= {shift_reg[DELAY-2:0], 1'b1};
  end

endmodule // init_rst
