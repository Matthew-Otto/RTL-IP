module axi_lite_bram #(
    parameter int MEM_DEPTH  = 32,
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
) (
    input  logic       clk,
    input  logic       reset,

    axi_lite_if.slave  s_axi
);

    localparam WORD_OFFSET = DATA_WIDTH / 8;
    localparam ADDR_ALIGN = $clog2(WORD_OFFSET);

    localparam
        RSP_OKAY = 2'b00,
        RSP_EXOKAY = 2'b01,
        RSP_SLVERR = 2'b10,
        RSP_DECERR = 2'b11;

    ///////////////////////////////////////////////////////
    //// BRAM /////////////////////////////////////////////
    ///////////////////////////////////////////////////////

    logic [(DATA_WIDTH/8)-1:0] wr_en;
    logic [DATA_WIDTH-1:0] mem [MEM_DEPTH-1:0];

    always_ff @(posedge clk) begin
        for (int i = 0; i < (DATA_WIDTH / 8); i++) begin
            if (wr_en[i])
                mem[waddr_b>>ADDR_ALIGN][(i*8) +: 8] <= data_b[(i*8) +: 8];
        end
        s_axi.rdata <= mem[s_axi.araddr>>ADDR_ALIGN];
    end

    logic [ADDR_WIDTH-1:0]     waddr_b;
    logic [DATA_WIDTH-1:0]     data_b;
    logic [(DATA_WIDTH/8)-1:0] data_strb_b;

    always_ff @(posedge clk) begin
        if (s_axi.awready && s_axi.awvalid)
            waddr_b <= s_axi.awaddr;

        if (s_axi.wready && s_axi.wvalid) begin
            data_b <= s_axi.wdata;
            data_strb_b <= s_axi.wstrb;
        end
    end


    ///////////////////////////////////////////////////////
    //// AXI-Lite write port //////////////////////////////
    ///////////////////////////////////////////////////////

    enum {
        W_READY,
        W_VALID_ADDR,
        W_VALID_DATA,
        W_BRAM,
        W_READY_PEND_RSP,
        W_VALID_ADDR_PEND_RSP,
        W_VALID_DATA_PEND_RSP,
        W_BRAM_PEND_RSP
    } wr_state, next_wr_state;

    always_ff @(posedge clk)
        if (reset) wr_state <= W_READY;
        else       wr_state <= next_wr_state;

    always_comb begin
        next_wr_state = wr_state;
        s_axi.awready = 0;
        s_axi.wready = 0;
        s_axi.bvalid = 0;
        s_axi.bresp = RSP_OKAY;

        for (int i = 0; i < DATA_WIDTH/8; i++)
            wr_en[i] = '0;

        case (wr_state)
            // buffer is empty, no responses pending
            W_READY : begin
                s_axi.awready = 1;
                s_axi.wready = 1;

                case ({s_axi.awvalid, s_axi.wvalid})
                    2'b11 : next_wr_state = W_BRAM;
                    2'b10 : next_wr_state = W_VALID_ADDR;
                    2'b01 : next_wr_state = W_VALID_DATA;
                    default: next_wr_state = wr_state;
                endcase
            end

            // buffered address, need data
            W_VALID_ADDR : begin
                s_axi.wready = 1;
                if (s_axi.wvalid)
                    next_wr_state = W_BRAM;
            end

            // buffered data, need address
            W_VALID_DATA : begin
                s_axi.awready = 1;
                if (s_axi.awvalid)
                    next_wr_state = W_BRAM;
            end

            // addr + data are valid, write to bram, send response
            W_BRAM : begin
                s_axi.bvalid = 1;

                wr_en = data_strb_b;
                s_axi.awready = 1;
                s_axi.wready = 1;

                case ({s_axi.awvalid, s_axi.wvalid, s_axi.bready})
                    3'b001 : next_wr_state = W_READY;
                    3'b101 : next_wr_state = W_VALID_ADDR;
                    3'b011 : next_wr_state = W_VALID_DATA;
                    3'b111 : next_wr_state = W_BRAM;
                    3'b000 : next_wr_state = W_READY_PEND_RSP;
                    3'b100 : next_wr_state = W_VALID_ADDR_PEND_RSP;
                    3'b010 : next_wr_state = W_VALID_DATA_PEND_RSP;
                    3'b110 : next_wr_state = W_BRAM_PEND_RSP;
                endcase
            end

            // buffer empty but pending response
            W_READY_PEND_RSP : begin
                s_axi.bvalid = 1;

                s_axi.awready = 1;
                s_axi.wready = 1;
                case ({s_axi.awvalid, s_axi.wvalid, s_axi.bready})
                    3'b111 : next_wr_state = W_BRAM;
                    3'b101 : next_wr_state = W_VALID_ADDR;
                    3'b011 : next_wr_state = W_VALID_DATA;
                    3'b001 : next_wr_state = W_READY;
                    3'b110 : next_wr_state = W_BRAM_PEND_RSP;
                    3'b100 : next_wr_state = W_VALID_ADDR_PEND_RSP;
                    3'b010 : next_wr_state = W_VALID_DATA_PEND_RSP;
                    3'b000 : next_wr_state = W_READY_PEND_RSP;
                endcase
            end

            // buffered addr but previous response pending
            W_VALID_ADDR_PEND_RSP : begin
                s_axi.bvalid = 1;

                s_axi.wready = 1;
                case ({s_axi.wvalid, s_axi.bready})
                    2'b10 : next_wr_state = W_BRAM_PEND_RSP;
                    2'b01 : next_wr_state = W_VALID_ADDR;
                    2'b11 : next_wr_state = W_BRAM;
                    2'b00 : next_wr_state = W_VALID_ADDR_PEND_RSP;
                endcase
            end

            // buffered data but previous response pendingwr_en
            W_VALID_DATA_PEND_RSP : begin
                s_axi.bvalid = 1;

                s_axi.awready = 1;
                case ({s_axi.awvalid, s_axi.bready})
                    2'b10 : next_wr_state = W_BRAM_PEND_RSP;
                    2'b01 : next_wr_state = W_VALID_DATA;
                    2'b11 : next_wr_state = W_BRAM;
                    2'b00 : next_wr_state = W_VALID_DATA_PEND_RSP;
                endcase
            end

            // valid buffer but previous response pending
            W_BRAM_PEND_RSP : begin
                s_axi.bvalid = 1;
                if (s_axi.bready)
                    next_wr_state = W_BRAM;
            end

            default : next_wr_state = W_READY;
        endcase
    end


    ///////////////////////////////////////////////////////
    //// AXI-Lite read port ///////////////////////////////
    ///////////////////////////////////////////////////////

    assign s_axi.arready = 1'b1;
    assign s_axi.rresp = RSP_OKAY;

    always_ff @(posedge clk) begin
        if (reset)
            s_axi.rvalid <= '0;
        else
            s_axi.rvalid <= s_axi.arvalid;
    end


endmodule