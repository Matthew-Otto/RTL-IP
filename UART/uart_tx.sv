// UART TX module

module uart_tx #(CLK_RATE, BAUD_RATE)(
    input  logic clk,
    input  logic reset,

    output logic tx,
    input  logic [7:0] data,
    output logic ready,
    input  logic valid
);

  localparam int PACKET_SIZE = 10;
  localparam int CLKS_PER_BAUD = CLK_RATE / BAUD_RATE;

  enum {
    IDLE,
    SHIFT,
    WAIT
  } state;

  logic [9:0] shift_reg;
  logic [31:0] clk_cnt;
  logic [3:0] bit_cnt;

  assign ready = state == IDLE;
  assign tx = (state == IDLE) ? 1 : shift_reg[bit_cnt];


  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
    end else begin
      case (state) 
        IDLE : begin
          bit_cnt <= 0;
          clk_cnt <= CLKS_PER_BAUD - 2;
          if (valid) begin
            shift_reg <= {1'b1, data, 1'b0};  // little endian (STOP, data, START)
            state <= WAIT;
          end
        end

        WAIT : begin
          if (clk_cnt == 0)
            state <= SHIFT;
          else
            state <= WAIT;
          clk_cnt <= clk_cnt - 1;
        end

        SHIFT : begin
          clk_cnt <= CLKS_PER_BAUD - 2;
          if (bit_cnt == (PACKET_SIZE-1)) begin
            state <= IDLE;
          end else begin
            bit_cnt <= bit_cnt + 1;
            state <= WAIT;
          end
        end

        default : state <= IDLE;
      endcase
    end
  end

endmodule // uart_tx