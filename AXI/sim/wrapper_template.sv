module wrapper_template;
    logic clk;
    logic reset;

    localparam int NUM_REGS       = 4;
    localparam int AXI_DATA_WIDTH = 32;
    logic [AXI_DATA_WIDTH-1:0] core_i [NUM_REGS-1:0];
    logic [AXI_DATA_WIDTH-1:0] core_o [NUM_REGS-1:0];

    // 2. Instantiate the Interface (defined by macro)
    `INTF_TYPE axi ();

    // 3. Instantiate the DUT (defined by macro)
    `DUT_NAME dut (
        .clk(clk),
        .reset(reset),
        .s_axi(axi.slave),
        .*
    );

endmodule : wrapper_template
