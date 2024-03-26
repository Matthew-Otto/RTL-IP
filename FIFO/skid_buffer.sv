module skid_buffer #(parameter DATA_WIDTH) (
    input  logic clk, reset,
    input  logic valid_in, ready_in,
    output logic valid_out, ready_out,
    input  logic [DATA_WIDTH-1:0] data_in, 
    output logic [DATA_WIDTH-1:0] data_out
);

logic valid_reg;
logic [DATA_WIDTH-1:0] data_reg;


always @(posedge clk or negedge reset) begin
    if (!reset) begin
        ready_out <= 1'b1;
        valid_out <= 1'b0;
        valid_reg <= 1'b0;
        
    // stall
    end else if (ready_out && ~ready_in && valid_out) begin
        ready_out <= 1'b0;
        valid_reg <= valid_in;
        if (valid_in)
            data_reg <= data_in;
    
    // resume
    end else if (~ready_out && ready_in) begin
        ready_out <= 1'b1;
        valid_out <= valid_reg;
        if (valid_reg)
            data_out <= data_reg;
    
    // normal operation
    end else if (ready_out) begin
        valid_out <= valid_in;
        if (valid_in)
            data_out <= data_in;
    end
end

endmodule: skid_buffer
