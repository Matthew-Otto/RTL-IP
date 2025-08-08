`timescale 1ns/1ps
module testbench();

integer handle3;
integer desc3;

logic clk, reset;
logic valid_in, valid_out;
logic ready_in, ready_out;
logic [7:0] data_in, data_out;
logic empty, almost_empty;

integer i;

// instantiate device to be tested
fifo #(.WIDTH(8), .DEPTH(10)) dut (
    .clk(clk),
    .reset(reset),
    .data_in(data_in),
    .data_in_val(valid_in),
    .data_in_rdy(ready_in),
    .data_out(data_out),
    .data_out_val(valid_out),
    .data_out_rdy(ready_out),
    .empty(empty),
    .almost_empty(almost_empty)
);
    
// 1 ns clock
initial begin
    clk = 1'b1;
    forever #1 clk = ~clk;
end

initial begin
    handle3 = $fopen("fifo.out");	
    desc3 = handle3;
end

always begin
    @(posedge clk) begin
        $fdisplay(desc3, "");
    end
end


initial begin
    reset = 1'b0;
    #1 reset = 1'b1;
    #2 reset = 1'b0;

    data_in = $urandom();
    valid_in = 1;
    
    for (i=0; i < 100; i=i+1) begin
        
        @(posedge clk) begin
            if (ready_in && valid_in)
                data_in = $urandom();

            valid_in = $urandom();
            ready_out = $urandom();
        end
    end

    $writememh("fifo_cont.out", dut.buffer);
    $finish();
end

endmodule // testbench
