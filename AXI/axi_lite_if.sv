interface axi_lite_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)();

    // Write Address
    logic [ADDR_WIDTH-1:0]     awaddr;
    logic                      awvalid;
    logic                      awready;

    // Write Data
    logic [DATA_WIDTH-1:0]     wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;
    logic                      wvalid;
    logic                      wready;

    // Write Response
    logic [1:0]                bresp;
    logic                      bvalid;
    logic                      bready;

    // Read Address
    logic [ADDR_WIDTH-1:0]     araddr;
    logic                      arvalid;
    logic                      arready;

    // Read Data
    logic [DATA_WIDTH-1:0]     rdata;
    logic [1:0]                rresp;
    logic                      rvalid;
    logic                      rready;

    
    modport master (
        // Write Address
        output awaddr, awvalid,
        input  awready,

        // Write Data
        output wdata, wstrb, wvalid,
        input  wready,

        // Write Response
        input  bresp, bvalid,
        output bready,

        // Read Address
        output araddr, arvalid,
        input  arready,

        // Read Data
        input  rdata, rresp, rvalid,
        output rready
    );


    modport slave (
        // Write Address
        input  awaddr, awvalid,
        output awready,

        // Write Data
        input  wdata, wstrb, wvalid,
        output wready,

        // Write Response
        output bresp, bvalid,
        input  bready,

        // Read Address
        input  araddr, arvalid,
        output arready,

        // Read Data
        output rdata, rresp, rvalid,
        input  rready
    );

endinterface : axi_lite_if
