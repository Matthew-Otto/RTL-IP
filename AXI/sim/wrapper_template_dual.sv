module wrapper_template_dual;
    logic clk;
    logic reset;

    localparam int AXI_DATA_WIDTH = 32;

    // Instantiate the Interface (defined by macro)
    `INTF_TYPE axi_a ();
    `INTF_TYPE axi_b ();

    // Instantiate the DUT (defined by macro)
    `DUT_NAME dut (
        .clk(clk),
        .reset(reset),
        .s_axi_a(axi_a.slave),
        .s_axi_b(axi_b.slave),
        .*
    );

endmodule : wrapper_template_dual
