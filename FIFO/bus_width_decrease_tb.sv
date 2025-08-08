`timescale 1ns/1ps
module testbench();

integer handle3;
integer desc3;

logic clk, reset;
logic [31:0] data_in;
logic [7:0] data_out;
logic valid_in, valid_out, input_ready, output_ready;

integer i;

// instantiate device to be tested
bus_width_decrease #(.SIZE_IN(32), .SIZE_OUT(8)) dut (
    .clk(clk),
    .input_ready(input_ready),
    .input_valid(valid_in),
    .data_in(data_in),
    .output_ready(output_ready),
    .output_valid(valid_out),
    .data_out(data_out)
);
    
// 1 ns clock
initial begin
    clk = 1'b1;
    forever #1 clk = ~clk;
end

initial begin
    handle3 = $fopen("bwa.out");	
    desc3 = handle3;
end

always begin
    @(posedge clk) begin
        $fdisplay(desc3, "ready in: %b out: %b | data_in: %h | valid_in: %b | data_out: %h | valid_out: %b", input_ready, output_ready, data_in, valid_in, data_out, valid_out);
    end
end


initial begin
    reset = 1'b0;
    #1 reset = 1'b1;
    #2 reset = 1'b0;
    
    for (i=0; i < 100; i=i+1) begin
        
        @(posedge clk) begin
            if (i % 5 == 0)
                output_ready <= 1;

            if (output_ready && valid_out)
                output_ready <= 0;

            if (input_ready) begin
                data_in = $urandom();
                valid_in = 1;
            end
        end
    end

    $finish();
end

endmodule // testbench
