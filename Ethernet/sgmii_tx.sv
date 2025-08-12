// sgmii tx engine
// generates and converts ethernet frames into 10b sgmii symbols to drive serdes

module sgmii_tx (
  input  logic       clk_125M,
  input  logic       reset,

  input  logic       sof,
  input  logic       eof,
  input  logic [7:0] data,

  output logic [9:0] tx_data
);

  logic control_symbol;
  logic [7:0] raw_byte;
  logic [2:0] preamble_cnt;

  localparam
    C_IDLE = 8'hBC;

  enum {
    IDLE,
    PREAMBLE,
    PACKET,
    INTER_PACKET
  } state, next_state;

  always_ff @(posedge clk_125M) begin
    if (reset) state <= IDLE;
    else       state <= next_state;

    if (reset) 
      preamble_cnt <= 0;
    else if (state == PREAMBLE)
      preamble_cnt <= preamble_cnt + 1;
  end

  always_comb begin
    next_state = state;
    control_symbol = 0;
    raw_byte = '0;

    case (state)
      IDLE : begin
        control_symbol = 1;
        raw_byte = C_IDLE;

        if (sof)
          next_state = PREAMBLE;
      end
      
      PREAMBLE : begin
        if (preamble_cnt == 3'h7) begin
          raw_byte = 8'hD5;
          next_state = PACKET;
        end else begin
          raw_byte = 8'h55;
        end
      end

      PACKET : begin
        raw_byte = buffer[0][7:0];
        if (buffer[0][8])
          next_state = IDLE;
      end
    endcase
  end

  encoder_8b10b encoder (
    .clk(clk_125M),
    .reset,
    .input_valid(1'b1),
    .input_ctrl(control_symbol),
    .input_data(raw_byte),
    .output_data(tx_data)
  );

  logic [8:0] buffer [8:0];

  always_ff @(posedge clk_125M) begin
    buffer[8] <= {eof,data};
    for (int i = 0; i < 8; i++) begin
      if (reset) buffer[i] <= 0;
      else buffer[i] <= buffer[i+1];
    end
  end

endmodule : sgmii_tx
