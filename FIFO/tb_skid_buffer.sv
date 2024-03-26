`timescale 1ns/1ps
module testbench();


logic clk, reset;
logic [7:0] data_in, data_out, sink;
logic data_val, data_val_out;
logic sink_ready, dut_ready;

integer i;

skid_buffer #(.DATA_WIDTH(8)) dut (
    .clk(clk),
    .reset(reset),
    .valid_in(data_val),
    .data_in(data_in),
    .valid_out(data_val_out),
    .data_out(data_out),
    .ready_in(sink_ready),
    .ready_out(dut_ready)
);
    
// 1 ns clock
initial begin
    clk = 1'b1;
    forever #5 clk = ~clk;
end

always @(posedge clk) begin
    if (dut_ready)
        data_in <= $random;

    if (data_val_out && sink_ready)
        sink <= data_out;
end

initial begin
    reset = 1;
    #8 reset = 0;
    #66 reset = 1;
    sink_ready = 1;
    data_val = 1;

    for (i=0; i < 20; i=i+1) begin
        
        @(posedge clk) begin

            if (i == 4)
                sink_ready <= 0;

            if (i == 6)
                data_val <= 1;
            if (i == 7)
                data_val <= 1;
            if (i == 9)
                sink_ready <= 1;

            if (i == 12)
                data_val <= 0;
            if (i == 14) begin
                sink_ready <= 0;
                data_val <= 1;
            end
            if (i == 16)
                sink_ready <= 1;
            
        end // @(negedge clk)
    end // for i

    $finish;
end


endmodule // testbench
