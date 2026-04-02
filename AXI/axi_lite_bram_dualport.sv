module axi_lite_bram_dualport #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
) (
    input  logic       clk,
    input  logic       reset,

    axi_lite_if.slave  s_axi_a,
    axi_lite_if.slave  s_axi_b
);

    localparam WORD_COUNT = DATA_WIDTH / 8;
    localparam ADDR_ALIGN = $clog2(WORD_COUNT);
    localparam ALIGNED_ADDR_WIDTH = ADDR_WIDTH - ADDR_ALIGN;

    // AXI Port A
    logic [(DATA_WIDTH/8)-1:0]     wr_en_a;
    logic [ALIGNED_ADDR_WIDTH-1:0] write_addr_a;
    logic [DATA_WIDTH-1:0]         write_data_a;
    logic [ALIGNED_ADDR_WIDTH-1:0] read_addr_a;
    logic [DATA_WIDTH-1:0]         read_data_a;
    // AXI Port B
    logic [(DATA_WIDTH/8)-1:0]     wr_en_b;
    logic [ALIGNED_ADDR_WIDTH-1:0] write_addr_b;
    logic [DATA_WIDTH-1:0]         write_data_b;
    logic [ALIGNED_ADDR_WIDTH-1:0] read_addr_b;
    logic [DATA_WIDTH-1:0]         read_data_b;

    ///////////////////////////////////////////////////////
    //// BRAM /////////////////////////////////////////////
    ///////////////////////////////////////////////////////

    dual_port_bram #(
        .ADDR_WIDTH(ALIGNED_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) bram (
        .clk,
        .wr_en_a,
        .write_addr_a,
        .write_data_a,
        .read_addr_a,
        .read_data_a,
        .wr_en_b,
        .write_addr_b,
        .write_data_b,
        .read_addr_b,
        .read_data_b
    );

    ///////////////////////////////////////////////////////
    //// Port A ///////////////////////////////////////////
    ///////////////////////////////////////////////////////
        
    axi_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_lite_port_a (
        .clk,
        .reset,
        .s_axi(s_axi_a),
        .wr_en(wr_en_a),
        .write_addr(write_addr_a),
        .write_data(write_data_a),
        .read_addr(read_addr_a),
        .read_data(read_data_a)
    );
        
    ///////////////////////////////////////////////////////
    //// Port B ///////////////////////////////////////////
    ///////////////////////////////////////////////////////

    axi_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_lite_port_b (
        .clk,
        .reset,
        .s_axi(s_axi_b),
        .wr_en(wr_en_b),
        .write_addr(write_addr_b),
        .write_data(write_data_b),
        .read_addr(read_addr_b),
        .read_data(read_data_b)
    );

endmodule : axi_lite_bram_dualport




module axi_lite_slave #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32,
    
    localparam WORD_COUNT = DATA_WIDTH / 8,
    localparam ADDR_ALIGN = $clog2(WORD_COUNT),
    localparam ALIGNED_ADDR_WIDTH = ADDR_WIDTH - ADDR_ALIGN
) (
    input  logic                          clk,
    input  logic                          reset,

    axi_lite_if.slave                     s_axi,

    output logic [(DATA_WIDTH/8)-1:0]     wr_en,
    output logic [ALIGNED_ADDR_WIDTH-1:0] write_addr,
    output logic [DATA_WIDTH-1:0]         write_data,
    output logic [ALIGNED_ADDR_WIDTH-1:0] read_addr,
    input  logic [DATA_WIDTH-1:0]         read_data
);



    localparam
        RSP_OKAY = 2'b00,
        RSP_EXOKAY = 2'b01,
        RSP_SLVERR = 2'b10,
        RSP_DECERR = 2'b11;

    ///////////////////////////////////////////////////////
    //// AXI-Lite write port //////////////////////////////
    ///////////////////////////////////////////////////////

    logic [(DATA_WIDTH/8)-1:0] data_strb;

    always_ff @(posedge clk) begin
        if (s_axi.awready && s_axi.awvalid)
            write_addr <= s_axi.awaddr >> ADDR_ALIGN;

        if (s_axi.wready && s_axi.wvalid) begin
            write_data <= s_axi.wdata;
            data_strb <= s_axi.wstrb;
        end
    end

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

                wr_en = data_strb;
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

    assign read_addr = s_axi.araddr >> ADDR_ALIGN;
    assign s_axi.rdata = read_data;

    always_ff @(posedge clk) begin
        if (reset)
            s_axi.rvalid <= '0;
        else
            s_axi.rvalid <= s_axi.arvalid;
    end

endmodule : axi_lite_slave




module dual_port_bram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  logic                     clk,

    // Port A
    input  logic [(DATA_WIDTH/8)-1:0] wr_en_a,
    input  logic [ADDR_WIDTH-1:0]     write_addr_a,
    input  logic [DATA_WIDTH-1:0]     write_data_a,
    input  logic [ADDR_WIDTH-1:0]     read_addr_a,
    output logic [DATA_WIDTH-1:0]     read_data_a,

    // Port B
    input  logic [(DATA_WIDTH/8)-1:0] wr_en_b,
    input  logic [ADDR_WIDTH-1:0]     write_addr_b,
    input  logic [DATA_WIDTH-1:0]     write_data_b,
    input  logic [ADDR_WIDTH-1:0]     read_addr_b,
    output logic [DATA_WIDTH-1:0]     read_data_b
);

    localparam MEM_DEPTH = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [MEM_DEPTH-1:0];

    // Port A
    always_ff @(posedge clk) begin
        for (int i = 0; i < (DATA_WIDTH / 8); i++) begin
            if (wr_en_a[i])
                mem[write_addr_a][(i*8) +: 8] <= write_data_a[(i*8) +: 8];
        end
        read_data_a <= (wr_en_a && (read_addr_a == write_addr_a)) ? write_data_a : mem[read_addr_a];
    end

    // Port B
    always_ff @(posedge clk) begin
        for (int i = 0; i < (DATA_WIDTH / 8); i++) begin
            if (wr_en_b[i])
                mem[write_addr_b][(i*8) +: 8] <= write_data_b[(i*8) +: 8];
        end
        read_data_b <= (wr_en_b && (read_addr_b == write_addr_b)) ? write_data_b : mem[read_addr_b];
    end

endmodule