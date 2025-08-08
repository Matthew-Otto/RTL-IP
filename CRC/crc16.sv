// CRC16-CCITT streaming implementation
// consumes one bit per cycle

module crc16 #(parameter logic [15:0] POLYNOMIAL = 16'h1021) (
  input  logic clk,
  input  logic reset,

  input  logic valid,
  input  logic data,

  output logic crc_error
);

  logic [15:0] crc;

  assign crc_error = |crc;

  always_ff @(posedge clk) begin
    if (reset)
      crc <= 0;
    else if (valid) begin
      if (POLYNOMIAL[0])
        crc[0] <= data ^ crc[15];
      else
        crc[0] <= data;

      for (int i = 1; i < 16; i++) begin
        if (POLYNOMIAL[i])
          crc[i] <= crc[i-1] ^ crc[15];
        else
          crc[i] <= crc[i-1];
      end
    end
  end

endmodule : crc16
