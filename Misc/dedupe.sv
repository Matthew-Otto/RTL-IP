// Takes <WORD_CNT> words of width <WORD_WIDTH> and removes duplicate words from the output.
// Each output word includes a count value that describes the number of instances of 
// that word in the input.

module dedupe #(
  parameter WORD_WIDTH = 16,
  parameter WORD_CNT = 8
)(
  input logic clk,
  input  logic [WORD_WIDTH*WORD_CNT-1:0] data_in,
  output logic [LOG2_WORD_CNT-1:0]       data_out_cnt [WORD_CNT-1:0]
);

  localparam LOG2_WORD_CNT = $clog2(WORD_CNT);

  localparam COMP_CNT = WORD_CNT * (WORD_CNT-1) / 2;


  logic [WORD_WIDTH-1:0]    input_words [WORD_CNT-1:0];

  logic [COMP_CNT-1:0]      comp;
  logic [LOG2_WORD_CNT-1:0] dupe_cnt [WORD_CNT-1:0];
  logic [WORD_CNT-1:0]      disable_out;

  // split input bus into separate words
  always_comb begin : split_input
    for (int i = 0; i < WORD_CNT; i++)
      input_words[i] = data_in[i*WORD_WIDTH+:WORD_WIDTH];
  end

  // compare each word
  always_comb begin : compare
    int k = 0;
    for (int i = 0; i < (WORD_CNT-1); i++) begin
      for (int j = (i+1); j < WORD_CNT; j++) begin
        comp[k] = (input_words[i] == input_words[j]);
        k++;
      end
    end
  end

  // count number of duplicates
  always_comb begin : count_duplicates
    int k = 0;
    for (int i = 0; i < (WORD_CNT-1); i++) begin
      dupe_cnt[i] = 1;
      for (int j = (i+1); j < WORD_CNT; j++) begin
        dupe_cnt[i] = dupe_cnt[i] + comp[k];
        k++;
      end
    end
    dupe_cnt[WORD_CNT-1] = 1;
  end

  // disable all duplicated words except one
  always_comb begin : dedupe
    disable_out = '0;
    for (int i = 1; i < WORD_CNT; i++) begin
      int idx = i-1;
      disable_out[i] = comp[idx];
      if (i > 1) begin
        for (int j = (WORD_CNT-2); j >= (WORD_CNT-i); j--) begin
          idx += j;
          disable_out[i] = disable_out[i] | comp[idx];
        end
      end
    end

    for (int i = 0; i < WORD_CNT; i++)
      data_out_cnt[i] = disable_out[i] ? 0 : dupe_cnt[i];
  end

endmodule : dedupe
