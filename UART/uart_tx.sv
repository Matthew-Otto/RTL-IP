// UART TX module

module uart_tx #(CLK_RATE, BAUD_RATE)(
    input clk,
    input areset,
    input data_write_valid,
    input [7:0] data_in,

    output logic data_write_ready,
    output logic tx
);

localparam int PACKET_SIZE = 10;
localparam int CLKS_PER_BAUD = CLK_RATE / BAUD_RATE;

localparam 
    IDLE  = 2'b00,
    LOAD  = 2'b01,
    SHIFT = 2'b10,
    WAIT  = 2'b11;

logic [1:0] state;
logic [9:0] shift_reg;
logic [31:0] clk_cnt;
logic [3:0] bit_cnt;

logic buffer_full;
logic [7:0] data_reg;


assign data_write_ready = ~buffer_full;
assign tx = shift_reg[bit_cnt];

always @(posedge clk, posedge areset) begin
    if (areset) begin
        data_reg <= 0;
        buffer_full <= 0;
    end else begin
        if (data_write_valid == 1 && buffer_full == 0) begin
            data_reg <= data_in;
            buffer_full <= 1;
        end else if (state == LOAD) begin
            buffer_full <= 0;
        end
    end
end


always @(posedge clk, posedge areset) begin
    if (areset) begin
        shift_reg <= 10'b1;
        state <= IDLE;
        bit_cnt <= 0;
    end else begin
        case (state) 
            IDLE : begin
                if (buffer_full)
                    state <= LOAD;
                else
                    state <= IDLE;
            end

            LOAD : begin
                shift_reg <= {1'b1, data_reg, 1'b0};  // little endian (STOP, data, START)

                clk_cnt <= CLKS_PER_BAUD - 2;
                bit_cnt <= 0;
                state <= WAIT;
            end

            WAIT : begin
                if (clk_cnt == 0)
                    state <= SHIFT;
                else
                    state <= WAIT;
                clk_cnt <= clk_cnt - 1;
            end

            SHIFT : begin
                clk_cnt <= CLKS_PER_BAUD - 2;
                if (bit_cnt == (PACKET_SIZE-1)) begin
                    if (buffer_full)
                        state <= LOAD;
                    else
                        state <= IDLE;
                end else begin
                    bit_cnt <= bit_cnt + 1;
                    state <= WAIT;
                end
            end
        endcase
    end
end


endmodule // uart_tx