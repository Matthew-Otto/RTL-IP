// bus width adapter
// takes an input from a wider bus and outputs to a narrower bus over multiple cycles
// when LITTLE_ENDIAN is 1, LSB of output bus is output first
module bus_width_decrease #(SIZE_IN=32, SIZE_OUT=8, LITTLE_ENDIAN=1)(
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
    assert (SIZE_IN % SIZE_OUT == 0) else $error("SIZE_IN must be a multiple of SIZE_OUT");

  localparam BUFF_SIZE = SIZE_IN / SIZE_OUT;

  localparam BUFF_EMPTY_PTR = LITTLE_ENDIAN ? (BUFF_SIZE)-1 : 0;
  localparam BUFF_FULL_PTR = LITTLE_ENDIAN ? 0 : (BUFF_SIZE)-1;




  logic [$clog2(BUFF_SIZE)-1:0] ptr, next_ptr, ptr_iter;
  logic [SIZE_IN-1:0] buffer;
  logic [SIZE_OUT-1:0] skid_buffer;
  logic overflow;

  generate
    if (LITTLE_ENDIAN)
      assign ptr_iter = ptr + 1;
    else
      assign ptr_iter = ptr - 1;
  endgenerate


  enum {
    EMPTY,
    NOT_EMPTY,
    ALMOST_EMPTY,
    OVERFLOW
  } state, next_state;

  always_ff @(posedge clk) begin
    if (reset) state <= EMPTY;
    else state <= next_state;

    if (reset) ptr <= BUFF_FULL_PTR;
    else ptr <= next_ptr;
  end

  always_comb begin
    next_state = state;
    next_ptr = ptr;
    input_ready = 0;
    output_valid = 0;
    overflow = 0;
    output_data = buffer[ptr*SIZE_OUT+:SIZE_OUT];

    case (state)
      EMPTY : begin
        input_ready = 1;

        if (input_valid)
          next_state = NOT_EMPTY;
      end

      NOT_EMPTY : begin
        output_valid = 1;

        if (output_ready) begin
          next_ptr = ptr_iter;
          if (ptr_iter == BUFF_EMPTY_PTR)
            next_state = ALMOST_EMPTY;
        end
      end

      ALMOST_EMPTY : begin
        input_ready = 1;
        output_valid = 1;

        if (input_valid || output_ready)
          next_ptr = BUFF_FULL_PTR;

        case ({input_valid, output_ready})
          2'b11 : next_state = NOT_EMPTY;
          2'b01 : next_state = EMPTY;
          2'b10 : begin
            overflow = 1;
            next_state = OVERFLOW;
          end
          default;
        endcase
      end

      OVERFLOW : begin
        output_valid = 1;
        output_data = skid_buffer;

        if (output_ready)
          next_state = NOT_EMPTY;
      end
    endcase
  end

  always_ff @(posedge clk) begin
    if (input_valid && input_ready)
      buffer <= input_data;

    if (overflow)
      skid_buffer <= output_data;
  end

endmodule : bus_width_decrease
