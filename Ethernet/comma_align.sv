// searches for a comma (8b/10b K28.5) in a bitstring across two 10 bit parallel words
// and computes the number of bitslips required to align symbols to the 10 bit word boundary

module comma_align (
  input  logic       clk,
  input  logic       reset,

  input  logic [9:0] input_data,
  output logic [3:0] offset,
  output logic       comma
);

  logic [8:0]  last_word;
  logic [18:0] search_word;
  logic [9:0]  match;

  always_ff @(posedge clk) begin
    if (reset)
      last_word <= 0;
    else
      last_word <= input_data[8:0];
  end

  assign search_word = {last_word,input_data};

  always_comb begin
    for (logic [4:0] i = 0; i < 10; i++) begin
      match[i] = (search_word[i+:10] == 10'b0011111010) || (search_word[i+:10] == 10'b1100000101);
    end

    offset = 0;
    comma = 1;
    case (match)
      10'b00000_00001 : offset = 0;
      10'b00000_00010 : offset = 1;
      10'b00000_00100 : offset = 2;
      10'b00000_01000 : offset = 3;
      10'b00000_10000 : offset = 4;
      10'b00001_00000 : offset = 5;
      10'b00010_00000 : offset = 6;
      10'b00100_00000 : offset = 7;
      10'b01000_00000 : offset = 8;
      10'b10000_00000 : offset = 9;
      default : comma = 0;
    endcase
  end

endmodule : comma_align
