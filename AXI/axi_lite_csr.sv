// AXI4-Lite Control and Status Register Slave Interface
// Core can set bits by driving the corresponding bit in core_i
// Registers can be read by AXI, write one to clear.

module axi_lite_csr #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 12,
    parameter int NUM_REGS   = 4
) (
    input  logic                                clk,
    input  logic                                reset,

    // AXI4-Lite Slave Interface
    axi_lite_if.slave                           s_axi,

    // Core interface
    input  logic [NUM_REGS-1:0][DATA_WIDTH-1:0] core_set,
    input  logic [NUM_REGS-1:0][DATA_WIDTH-1:0] core_clr,
    output logic [NUM_REGS-1:0][DATA_WIDTH-1:0] csr_out
);

    // Calculate number of lower address bits to drop based on data width
    localparam int ADDR_LSB = $clog2(DATA_WIDTH/8);
    // Calculate number of bits required to address NUM_REGS
    localparam int OPT_MEM_ADDR_BITS = (NUM_REGS > 1) ? $clog2(NUM_REGS) : 1;

    // Internal Signals
    logic [NUM_REGS-1:0][DATA_WIDTH-1:0] csr_reg;
    logic                                axi_wr_en;
    logic                                axi_rd_en;

    logic [OPT_MEM_ADDR_BITS-1:0] wr_idx;
    logic [OPT_MEM_ADDR_BITS-1:0] rd_idx;

    assign csr_out = csr_reg;

    // -------------------------------------------------------------------------
    // AXI-Lite Write Logic
    // -------------------------------------------------------------------------
    assign s_axi.awready = !s_axi.bvalid;
    assign s_axi.wready  = !s_axi.bvalid;
    
    assign axi_wr_en = s_axi.awvalid && s_axi.wvalid && s_axi.awready && s_axi.wready;
    
    // Drop the byte-addressable bits to get the register array index
    assign wr_idx = s_axi.awaddr >> ADDR_LSB; 

    assign s_axi.bresp = 2'b00; // OKAY response

    always_ff @(posedge clk) begin
        if (reset) begin
            s_axi.bvalid <= 1'b0;
        end else begin
            if (axi_wr_en && !s_axi.bvalid) begin
                s_axi.bvalid <= 1'b1;
            end else if (s_axi.bready && s_axi.bvalid) begin
                s_axi.bvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // AXI-Lite Read Logic
    // -------------------------------------------------------------------------
    assign s_axi.arready = !s_axi.rvalid;
    assign axi_rd_en      = s_axi.arvalid && s_axi.arready;
    
    assign rd_idx = s_axi.araddr >> ADDR_LSB;

    assign s_axi.rresp = 2'b00; // OKAY response

    always_ff @(posedge clk) begin
        if (reset) begin
            s_axi.rvalid <= 1'b0;
            s_axi.rdata  <= '0;
        end else begin
            if (axi_rd_en) begin
                s_axi.rvalid <= 1'b1;
                // Read out data if within bounds, otherwise return 0s
                if (rd_idx < NUM_REGS) begin
                    s_axi.rdata <= csr_reg[rd_idx];
                end else begin
                    s_axi.rdata <= '0; 
                end
            end else if (s_axi.rvalid && s_axi.rready) begin
                s_axi.rvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // CSR State Update Logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            csr_reg <= '0;
        end else begin
            // Core update
            for (int i = 0; i < NUM_REGS; i++) begin
                csr_reg[i] <= (csr_reg[i] | core_set[i]) & ~core_clr[i];
            end

            // AXI update, overwrites core
            if (axi_wr_en && (wr_idx < NUM_REGS)) begin
                for (int b = 0; b < DATA_WIDTH/8; b++) begin
                    if (s_axi.wstrb[b]) begin
                        csr_reg[wr_idx][b*8+:8] <= s_axi.wdata[b*8+:8];
                    end
                end
            end
        end
    end

endmodule : axi_lite_csr
