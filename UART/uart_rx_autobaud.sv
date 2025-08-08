// autobaud UART RX module
// automatically determines baud rate of a frame
// requires each frame start with an odd syncword (LSB = 1)

module uart_rx_autobaud (
    input clk, rx, reset,
    output logic data_val,
    output logic [7:0] data
);

logic [23:0] symbol_period, tick;
logic [2:0] state;
logic [7:0] data_buffer;
logic [2:0] bit_count;

localparam [2:0]
    idle    = 3'b000,
    init    = 3'b001,
    start   = 3'b010,
    payload = 3'b011,
    stop    = 3'b100;


always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= idle;
        data <= 0;
        data_buffer <= 0;
        data_val <= 0;
    end else begin
        case (state)
            idle : begin // FSM should only return to idle in between frames
                if (~rx) begin
                    state <= init;
                    symbol_period <= 1;
                    data_val <= 0;
                end
            end

            init : begin
                if (rx) begin
                    state <= payload;
                    tick <= 1;
                    bit_count <= 0;
                end else
                    symbol_period <= symbol_period + 1;
            end

            start : begin
                // potential for opportunistic clock calibration here
                // if (rx) : update symbol period (average tick with previous period)
                // else wait for tick
                if (tick == symbol_period) begin
                    state <= payload;
                    tick <= 1;
                    bit_count <= 0;
                end else begin
                    tick <= tick + 1;
                end
            end

            payload : begin
                if (tick == symbol_period / 2) begin // sample in middle of symbol
                    data_buffer <= {rx, data_buffer[7:1]};
                end
                    
                if (tick == symbol_period) begin
                    tick <= 1;

                    if (bit_count < 7) begin
                        bit_count <= bit_count + 1;
                    end else begin
                        state <= stop;
                        data <= data_buffer;
                        data_val <= 1'b1;
                        tick <= 1;
                    end
                end else begin
                    tick <= tick + 1;
                end
            end

            stop : begin
                if (tick > symbol_period/4 && ~rx) begin
                    state <= start;
                    tick <= 1;
                    // update symbol period here
                end else if (tick == symbol_period * 2) begin
                    state <= idle;
                end else begin
                    tick <= tick + 1;
                end
            end
        endcase // state
    end

end // always clk

endmodule // uart_rx_autobaud
