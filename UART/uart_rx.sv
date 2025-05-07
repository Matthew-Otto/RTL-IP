// UART RX module

module uart_rx #(CLK_RATE, BAUD_RATE)(
    input clk,
    input areset,
    input rx,
    input ready,

    output logic data_val,
    output logic [7:0] data,
    output logic baud_rate_error
);

localparam int CLKS_PER_BAUD = CLK_RATE / BAUD_RATE;
localparam int HALF_CLKS_PER_BAUD = CLK_RATE / (BAUD_RATE * 2);



localparam
    IDLE   = 3'b000,
    START1 = 3'b001,
    START2 = 3'b010,
    DATA   = 3'b011,
    STOP   = 3'b100;

logic [2:0] state;
logic [31:0] clk_cnt;
logic [2:0] bit_cnt;

logic [7:0] data_reg;
logic flag;

// generate ready signal
always @(posedge clk, posedge areset) begin
    if (areset) begin
        data <= 8'bx;
        data_val <= 0;
    end else if (state == STOP && ~flag) begin
        // if data_val, overflow
        flag <= 1;
        data <= data_reg;
        data_val <= 1;
    end else if (state == IDLE) begin
        flag <= 0;
    end else if (data_val && ready) begin
        data_val <= 0;
    end
end


always @(posedge clk, posedge areset) begin
    if (areset) begin
        state <= IDLE;
        baud_rate_error <= 0;
    end else begin
        case (state)
            IDLE : begin
                clk_cnt <= 1;
                bit_cnt <= 0;
                if (~rx) state <= START1;
            end

            START1 : begin
                clk_cnt <= clk_cnt + 1;
                if (rx) begin
                    state <= IDLE;
                end else if (clk_cnt == HALF_CLKS_PER_BAUD) begin
                    state <= START2;
                end
            end

            START2 : begin
                if (clk_cnt == CLKS_PER_BAUD) begin
                    state <= DATA;
                    clk_cnt <= 1;
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end

            DATA : begin
                clk_cnt <= clk_cnt + 1;
                if (clk_cnt == HALF_CLKS_PER_BAUD) begin
                    data_reg[bit_cnt] <= rx;
                    clk_cnt <= clk_cnt + 1;
                end 
                if (clk_cnt == CLKS_PER_BAUD) begin
                    clk_cnt <= 1;
                    if (bit_cnt == 7)
                        state <= STOP;
                    bit_cnt <= bit_cnt + 1;
                end
            end

            STOP : begin
                if (clk_cnt == HALF_CLKS_PER_BAUD) begin
                    if (~rx)
                        baud_rate_error <= 1;
                    state <= IDLE;
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end

            default : state <= IDLE;
        endcase
    end
end

endmodule // uart_rx