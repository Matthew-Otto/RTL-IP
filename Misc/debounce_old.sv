module debouncer #(parameter DEBOUNCE_PERIOD=50000, parameter STROBE=1) (
    input clk,
    input button,
    output logic signal
);

logic debounced;
logic sync1, sync2;
logic [15:0] count = 0;

always @(posedge clk) begin
    sync1 <= button;
    sync2 <= sync1;

    if (count == 0) begin
        if (sync2 != debounced)
            count <= DEBOUNCE_PERIOD[15:0];
        debounced <= sync2;
    end else
        count <= count - 1;
end

if (STROBE) begin
    logic stb, lock;
    always @(posedge clk) begin
        if (debounced && ~lock) begin
            lock <= 1;
            stb <= 1;
        end
        
        if (stb)
            stb = 0;
        if (~debounced)
            lock = 0;
    end

    assign signal = stb;
end else begin
    assign signal = debounced;
end

endmodule  // debounce
