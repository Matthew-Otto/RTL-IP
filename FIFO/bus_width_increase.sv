// bus width adapter
// takes an input from a narrower bus over multiple cycles and outputs to a wider bus
// when LITTLE_ENDIAN is 1, LSB of output bus is populated first
module bus_width_increase #(SIZE_IN=8, SIZE_OUT=32, LITTLE_ENDIAN=1)(  
  input  logic                clk,
  input  logic                reset,

  output logic                input_ready,
  input  logic                input_valid,
  input  logic [SIZE_IN-1:0]  input_data,

  input  logic                output_ready,
  output logic                output_valid,
  output logic [SIZE_OUT-1:0] output_data
);

  initial
    assert (SIZE_OUT % SIZE_IN == 0) else $error("SIZE_OUT must be a multiple of SIZE_IN");

  localparam BUFF_SIZE = SIZE_OUT / SIZE_IN;

  localparam BUFF_EMPTY_PTR = LITTLE_ENDIAN ? 0 : (BUFF_SIZE)-1;
  localparam BUFF_FULL_PTR = LITTLE_ENDIAN ? (BUFF_SIZE)-1 : 0;
      
  logic [$clog2(BUFF_SIZE)-1:0] ptr, next_ptr, ptr_iter;
  logic [SIZE_IN-1:0] skid_buffer;
  logic overflow;
  logic resume;

  generate
    if (LITTLE_ENDIAN)
      assign ptr_iter = ptr + 1;
    else
      assign ptr_iter = ptr - 1;
  endgenerate

  assign overflow = (state == FULL) && ~output_ready;
  
  enum {
    NOT_FULL,
    FULL,
    OVERFLOW
  } state, next_state;

  always_ff @(posedge clk) begin
    if (reset) state <= NOT_FULL;
    else state <= next_state;

    if (reset) ptr <= BUFF_EMPTY_PTR;
    else ptr <= next_ptr;
  end

    
  always_comb begin
    next_state = state;
    next_ptr = ptr;
    resume = 0;

    case (state)
      NOT_FULL : begin
        input_ready = 1;
        output_valid = 0;

        if (input_valid) begin
          if (ptr == BUFF_FULL_PTR) begin
            next_ptr = BUFF_EMPTY_PTR;
            next_state = FULL;
          end else begin
            next_ptr = ptr_iter;
          end
        end
      end
      
      FULL : begin
        input_ready = 1;
        output_valid = 1;
        
        if (output_ready) begin
          next_state = NOT_FULL;
          if (input_valid)
            next_ptr = ptr_iter;
        end else if (input_valid) begin
          next_state = OVERFLOW;
        end
      end
      
      OVERFLOW : begin
        input_ready = 0;
        output_valid = 1;

        if (output_ready) begin
          resume = 1;
          next_state = NOT_FULL;
          next_ptr = ptr_iter;
        end
      end
    endcase
  end

  always_ff @(posedge clk) begin
    if ((input_valid && input_ready && ~overflow) || resume)
      output_data[ptr*SIZE_IN+:SIZE_IN] <= resume ? skid_buffer : input_data;

    if (input_valid && overflow)
      skid_buffer <= input_data;
  end

endmodule : bus_width_increase
