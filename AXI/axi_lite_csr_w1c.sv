// AXI4-Lite Control and Status Register Slave Interface
// Core can set bits by driving the corresponding bit in core_i
// Registers can be read by AXI, write one to clear.


// (w1c) write 1 to clear
module axi_lite_csr_w1c #(
    parameter int NUM_REGS       = 4,  // Number of registers
    parameter int AXI_DATA_WIDTH = 32
) (
    input  logic       clk,
    input  logic       reset,

    axi_lite_if.slave  s_axi,

    // core input sets bits by writing 1
    input  logic [AXI_DATA_WIDTH-1:0] core_i [NUM_REGS-1:0]
);

    // Address Decoding Parameters
    // Calculate word alignment
    // Ex: LSB 2 bits (bits 1:0) are ignored for 32 word alignment.
    localparam int ADDR_LSB = $clog2(AXI_DATA_WIDTH/8);
    // Calculate number of bits required to address NUM_REGS
    localparam int OPT_MEM_ADDR_BITS = $clog2(NUM_REGS);


    logic [AXI_DATA_WIDTH-1:0] registers [NUM_REGS-1:0]; // The Register File
    logic reg_we;
    logic [OPT_MEM_ADDR_BITS-1:0] write_index;
    logic [OPT_MEM_ADDR_BITS-1:0] read_index;

    assign s_axi.bresp = 2'b00; // OKAY
    assign s_axi.rresp = 2'b00; // OKAY

    //--------------------------------------------------------------------------
    // AXI Control Logic
    //--------------------------------------------------------------------------
    
    // Write Address Ready
    always_ff @(posedge clk) begin
        if (reset) begin
            s_axi.awready <= 1'b0;
        end else begin
            if (~s_axi.awready && s_axi.awvalid && s_axi.wvalid)
                s_axi.awready <= 1'b1;
            else
                s_axi.awready <= 1'b0;
        end
    end

    // Write Data Ready
    always_ff @(posedge clk) begin
        if (reset) begin
            s_axi.wready <= 1'b0;
        end else begin
            if (~s_axi.wready && s_axi.wvalid && s_axi.awvalid)
                s_axi.wready <= 1'b1;
            else
                s_axi.wready <= 1'b0;
        end
    end

    // Write Response
    always_ff @(posedge clk) begin
        if (reset) begin
            s_axi.bvalid <= 1'b0;
        end else begin
            if (s_axi.awready && s_axi.awvalid && s_axi.wready && s_axi.wvalid && ~s_axi.bvalid)
                s_axi.bvalid <= 1'b1;
            else if (s_axi.bready && s_axi.bvalid)
                s_axi.bvalid <= 1'b0;
        end
    end

    // Read Address Ready
    always_ff @(posedge clk) begin
        if (reset) begin
            s_axi.arready <= 1'b0;
        end else begin
            if (~s_axi.arready && s_axi.arvalid)
                s_axi.arready <= 1'b1;
            else
                s_axi.arready <= 1'b0;
        end
    end

    // Read Data Valid
    always_ff @(posedge clk) begin
        if (reset) begin
            s_axi.rvalid <= 1'b0;
        end else begin
            if (s_axi.arready && s_axi.arvalid && ~s_axi.rvalid)
                s_axi.rvalid <= 1'b1;
            else if (s_axi.rvalid && s_axi.rready)
                s_axi.rvalid <= 1'b0;
        end
    end

    //--------------------------------------------------------------------------
    // Address Decoding
    //--------------------------------------------------------------------------
    assign write_index = s_axi.awaddr[ADDR_LSB+:OPT_MEM_ADDR_BITS];
    assign read_index  = s_axi.araddr[ADDR_LSB+:OPT_MEM_ADDR_BITS];
    assign reg_we = s_axi.wready && s_axi.wvalid && s_axi.awready && s_axi.awvalid;

    //--------------------------------------------------------------------------
    // Register Logic: W1C (Software) + Set (Hardware)
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_REGS; i++) begin
                registers[i] <= '0;
            end
        end else begin
            for (int i = 0; i < NUM_REGS; i++) begin
                // --- AXI Clears Bit (W1C) (Priority 2)
                if (reg_we && (write_index == i)) begin
                    for (int j = 0; j < 32; j++) begin
                        if (s_axi.wdata[j] && s_axi.wstrb[j/8]) begin
                            registers[i][j] <= 1'b0;
                        end
                    end
                end

                // --- Core Sets Bits (Priority 1)
                registers[i] <= registers[i] | core_i[i];
            end
        end
    end

    //--------------------------------------------------------------------------
    // Read Data Mux
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            s_axi.rdata <= '0;
        end else if (s_axi.arready && s_axi.arvalid && ~s_axi.rvalid) begin
            if (read_index < NUM_REGS)
                s_axi.rdata <= registers[read_index];
            else
                s_axi.rdata <= '0;
        end
    end

endmodule : axi_lite_csr_w1c
