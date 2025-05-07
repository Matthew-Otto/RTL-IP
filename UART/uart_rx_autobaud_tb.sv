`timescale 1ns/1ps
module testbench();

integer handle3;
integer desc3;

logic clk, uclk, reset, rx;
logic [7:0] data;
logic data_val;

logic [71:0] testvector;

integer i;

assign testvector = {1'b1, 10'b1_01101000_0, 10'b1_01100101_0, 10'b1_01101100_0, 10'b1_01101100_0, 10'b1_01101111_0, 10'b1_00001010_0, 10'b1_01010101_0, 1'b1};



// instantiate device to be tested
uart_rx_autobaud dut (
    .clk(clk),
    .rx(rx),
    .reset(reset),
    .data(data),
    .data_val(data_val)
);
    
// 1 ns clock
initial begin
    clk = 1'b1;
    forever #1 clk = ~clk;
end

initial begin
    uclk = 1'b1;
    forever #100000 uclk = ~uclk;
end


initial begin
    handle3 = $fopen("uart.out");	
    desc3 = handle3;
end

always begin
    @(posedge clk) begin
        $fdisplay(desc3, "uclk: %b | %b | %b || val: %b | data: %b", uclk, reset, rx, data_val, data);
    end // @(posedge clk)
end


initial begin
    reset = 1'b1;
    #8 reset = 1'b0;
    #66 reset = 1'b1;

    for (i=0; i < 71; i=i+1) begin
        
        @(negedge uclk) begin

            rx = testvector[i];
            
        end // @(negedge clk)
    end
end

endmodule // testbench
