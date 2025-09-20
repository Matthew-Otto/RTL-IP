// syncrhonous FIFO with one write port and 4 read ports

module fifo_w1r4 #(
  parameter WIDTH = 8, 
  parameter DEPTH = 8
) (
  input  logic             clk,
  input  logic             reset,

  // input
  output logic             ready_in,
  input  logic             valid_in,
  input  logic [WIDTH-1:0] data_in,

  // output
  input  logic [3:0]       ready_out,
  output logic [3:0]       valid_out,
  output logic [WIDTH-1:0] data_out [3:0]
);

  localparam ADDR_SIZE = $clog2(DEPTH);

  logic [ADDR_SIZE-1:0] wr_ptr, rd_ptr, size;
  logic [WIDTH-1:0] mem [DEPTH-1:0];
  logic [WIDTH:0]   output_buffer [3:0];
  logic full, write;
  logic [3:0] read;
  logic [3:0] load;
  logic [2:0] read_cnt;

  logic [3:0] mem_val;

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      valid_out[i] = output_buffer[i][WIDTH];
      data_out[i] = output_buffer[i][WIDTH-1:0];
      read[i] = valid_out[i] && ready_out[i];

      load[i] = read[i] || ~valid_out[i];

      mem_val[i] = size > i;
    end
  end



  always_ff @(posedge clk) begin
    if (reset) begin
      output_buffer[0] <= '0;
      output_buffer[1] <= '0;
      output_buffer[2] <= '0;
      output_buffer[3] <= '0;
    end else begin
      case (load)
        4'b0000 : begin
          output_buffer[0] <= output_buffer[0];
          output_buffer[1] <= output_buffer[1];
          output_buffer[2] <= output_buffer[2];
          output_buffer[3] <= output_buffer[3];
        end
        4'b0001 : begin
          output_buffer[0] <= output_buffer[1];
          output_buffer[1] <= output_buffer[2];
          output_buffer[2] <= output_buffer[3];
          output_buffer[3] <= {mem_val[0],mem[rd_ptr]};
        end
        4'b0011 : begin
          output_buffer[0] <= output_buffer[2];
          output_buffer[1] <= output_buffer[3];
          output_buffer[2] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[3] <= {mem_val[1],mem[rd_ptr+1]};
        end
        4'b0101 : begin
          output_buffer[0] <= output_buffer[1];
          output_buffer[1] <= output_buffer[3];
          output_buffer[2] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[3] <= {mem_val[1],mem[rd_ptr+1]};
        end
        4'b1001 : begin
          output_buffer[0] <= output_buffer[1];
          output_buffer[1] <= output_buffer[2];
          output_buffer[2] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[3] <= {mem_val[1],mem[rd_ptr+1]};
        end
        4'b0111 : begin
          output_buffer[0] <= output_buffer[3];
          output_buffer[1] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[2] <= {mem_val[1],mem[rd_ptr+1]};
          output_buffer[3] <= {mem_val[2],mem[rd_ptr+2]};
        end
        4'b1011 : begin
          output_buffer[0] <= output_buffer[2];
          output_buffer[1] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[2] <= {mem_val[1],mem[rd_ptr+1]};
          output_buffer[3] <= {mem_val[2],mem[rd_ptr+2]};
        end
        4'b1101 : begin
          output_buffer[0] <= output_buffer[1];
          output_buffer[1] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[2] <= {mem_val[1],mem[rd_ptr+1]};
          output_buffer[3] <= {mem_val[2],mem[rd_ptr+2]};
        end
        4'b1111 : begin
          output_buffer[0] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[1] <= {mem_val[1],mem[rd_ptr+1]};
          output_buffer[2] <= {mem_val[2],mem[rd_ptr+2]};
          output_buffer[3] <= {mem_val[3],mem[rd_ptr+3]};
        end
        4'b0010 : begin
          output_buffer[1] <= output_buffer[2];
          output_buffer[2] <= output_buffer[3];
          output_buffer[3] <= {mem_val[0],mem[rd_ptr]};
        end
        4'b0110 : begin
          output_buffer[1] <= output_buffer[3];
          output_buffer[2] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[3] <= {mem_val[1],mem[rd_ptr+1]};
        end
        4'b1010 : begin
          output_buffer[1] <= output_buffer[2];
          output_buffer[2] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[3] <= {mem_val[1],mem[rd_ptr+1]};
        end
        4'b1110 : begin
          output_buffer[1] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[2] <= {mem_val[1],mem[rd_ptr+1]};
          output_buffer[3] <= {mem_val[2],mem[rd_ptr+2]};
        end
        4'b0100 : begin
          output_buffer[2] <= output_buffer[3];
          output_buffer[3] <= {mem_val[0],mem[rd_ptr]};
        end
        4'b1100 : begin
          output_buffer[2] <= {mem_val[0],mem[rd_ptr]};
          output_buffer[3] <= {mem_val[1],mem[rd_ptr+1]};
        end
        4'b1000 : begin
          output_buffer[3] <= {mem_val[0],mem[rd_ptr]};
        end
      endcase
    end
  end

  always_comb begin
    case (load)
      4'b0000 : read_cnt = 0;
      4'b0001,
      4'b0010,
      4'b0100,
      4'b1000 : read_cnt = (size >= 1) ? 1 : size;
      4'b0011,
      4'b0101,
      4'b0110,
      4'b1010,
      4'b1100,
      4'b1001 : read_cnt = (size >= 2) ? 2 : size;
      4'b0111,
      4'b1011,
      4'b1101,
      4'b1110 : read_cnt = (size >= 3) ? 3 : size;
      4'b1111 : read_cnt = (size >= 4) ? 4 : size;
    endcase
  end


  assign full = (size == DEPTH-1);

  assign ready_in = ~full;
  assign write = valid_in && ~full;

  always_ff @(posedge clk) begin
    if (reset) begin
      size <= 0;
      wr_ptr <= 0;
      rd_ptr <= 0;
    end else begin
      if (write) begin
        mem[wr_ptr] <= data_in;
        wr_ptr <= wr_ptr + 1;
      end

      if (|load) begin
        rd_ptr <= (read_cnt < size) ? rd_ptr + read_cnt : rd_ptr + size;
      end

      case ({write, |load})
        2'b11 : size <= (size + 1 < read_cnt) ? 0 : size + 1 - read_cnt;
        2'b10 : size <= size + 1;
        2'b01 : size <= (size < read_cnt) ? 0 : size - read_cnt;
        default;
      endcase
    end
  end

endmodule : fifo_w1r4
