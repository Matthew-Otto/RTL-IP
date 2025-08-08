// UART RX module

module uart_rx #(CLK_RATE=50000000, BAUD_RATE=115200)(
    input  logic clk,
    input  logic reset,

    input  logic rx,
    output logic [7:0] data,
    input  logic ready,
    output logic valid,
    output logic baud_rate_error,
    output logic sample  // strobes when UART module is sampling the input
);

  localparam int CLKS_PER_BAUD = CLK_RATE / BAUD_RATE;
  localparam int HALF_CLKS_PER_BAUD = CLK_RATE / (BAUD_RATE * 2);

  enum {
    IDLE,
    START1,
    START2,
    DATA,
    STOP
  } state;

  logic [31:0] clk_cnt;
  logic [2:0] bit_cnt;

  logic [7:0] data_reg;
  logic flag;

  assign sample = (state == DATA) && (clk_cnt == HALF_CLKS_PER_BAUD);

  // generate ready/valid signals
  always @(posedge clk) begin
    if (reset) begin
      data <= 8'bx;
      valid <= 0;
    end else if (state == STOP && ~flag) begin
      // if valid, overflow
      flag <= 1;
      data <= data_reg;
      valid <= 1;
    end else if (state == IDLE) begin
      flag <= 0;
    end else if (valid && ready) begin
      valid <= 0;
    end
  end


  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      baud_rate_error <= 0;
    end else begin
      case (state)
          IDLE : begin
            clk_cnt <= 1;
            bit_cnt <= 0;
            if (~rx) state <= START1;
          end

          START1 : begin
            clk_cnt <= clk_cnt + 1;
            if (rx) begin
              state <= IDLE;
            end else if (clk_cnt == HALF_CLKS_PER_BAUD) begin
              state <= START2;
            end
          end

          START2 : begin
            if (clk_cnt == CLKS_PER_BAUD) begin
              state <= DATA;
              clk_cnt <= 1;
            end else begin
              clk_cnt <= clk_cnt + 1;
            end
          end

          DATA : begin
            clk_cnt <= clk_cnt + 1;
            if (clk_cnt == HALF_CLKS_PER_BAUD) begin
              data_reg[bit_cnt] <= rx;
              clk_cnt <= clk_cnt + 1;
            end 
            if (clk_cnt == CLKS_PER_BAUD) begin
              clk_cnt <= 1;
              if (bit_cnt == 7)
                state <= STOP;
              bit_cnt <= bit_cnt + 1;
            end
          end

          STOP : begin
            if (clk_cnt == HALF_CLKS_PER_BAUD) begin
              if (~rx)
                baud_rate_error <= 1;
              state <= IDLE;
            end else begin
              clk_cnt <= clk_cnt + 1;
            end
          end

          default : state <= IDLE;
      endcase
    end
  end

endmodule : uart_rx
