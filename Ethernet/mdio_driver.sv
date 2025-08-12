// drives preconfigured values onto MDIO bus and reads back the results

module mdio_driver #(
  parameter CLK_DIV=50
)(
  input  logic clk,
  input  logic reset,

  output logic enet_mdc,
  inout  logic enet_mdio
);

  localparam ROM_SIZE = 4;
  localparam ROM_ADDR = $clog2(ROM_SIZE);

  logic [15:0] rom [ROM_SIZE-1:0];

  initial begin
    // enable auto crossover
    rom[0] = 16'b01_01_00000_10000_10;
    rom[1] = 16'b0000_0000_0110_0000;
    // reset
    rom[2] = 16'b01_01_00000_00000_10;
    rom[3] = 16'b1000_0000_0000_0000;
  end

  // clock divider
  localparam REAL_CLK_DIV = $clog2(CLK_DIV);
  logic slow_clk;
  logic [REAL_CLK_DIV:0] cnt;
  always @(posedge clk) begin
    if (reset) cnt <= 0;
    else       cnt <= cnt + 1;
  end
  assign slow_clk = cnt[REAL_CLK_DIV];
  assign enet_mdc = slow_clk;

  // shift register
  logic mdio_in;
  logic mdio_ien;
  logic mdio_out;
  logic mdio_oen;

  logic reg_wr_p;
  logic [15:0] shift_reg;
  logic [15:0] shift_reg_p;

  assign mdio_out = shift_reg[15];

  assign mdio_in = mdio_ien ? enet_mdio : 1'b0;
  assign enet_mdio = mdio_oen ? mdio_out : 1'bz;

  always_ff @(posedge slow_clk) begin
    for (int i = 0; i < 16; i++) begin
      if (i == 0) begin
        if (reset)
          shift_reg[i] <= 1'b0;
        else
          shift_reg[i] <= reg_wr_p ? shift_reg_p[i] : mdio_in;
      end else begin
        if (reset)
          shift_reg[i] <= 1'b0;
        else
          shift_reg[i] <= reg_wr_p ? shift_reg_p[i] : shift_reg[i-1];
      end
    end
  end


  // state machine
  logic              incr_ip;
  logic [ROM_ADDR:0] ip;
  logic [4:0]        bit_idx;

  enum {
    IDLE,
    PREAMBLE_H1,
    PREAMBLE_H2,
    INSTR_CTRL,
    INSTR_WRITE,
    INSTR_READ,
    HALT
  } state, next_state;

  always_ff @(posedge slow_clk) begin
    if (reset) state <= IDLE;
    else       state <= next_state;

    if (reset) ip <= 0;
    else if (incr_ip) ip <= ip + 1;

    if (reg_wr_p) bit_idx <= 15;
    else bit_idx <= bit_idx - 1;
    
  end

  always_comb begin
    next_state = state;
    reg_wr_p = 0;
    incr_ip = 0;
    mdio_ien = 0;
    mdio_oen = 0;

    case (state)
      IDLE : begin
        reg_wr_p = 1;
        shift_reg_p = 16'hFFFF;
        next_state = PREAMBLE_H1;
      end

      PREAMBLE_H1 : begin
        mdio_oen = 1;
        if (bit_idx == 0) begin
          reg_wr_p = 1;
          shift_reg_p = 16'hFFFF;
          next_state = PREAMBLE_H2;
        end
      end
      PREAMBLE_H2 : begin
        mdio_oen = 1;
        if (bit_idx == 0) begin
          reg_wr_p = 1;
          incr_ip = 1;
          shift_reg_p = rom[ip];
          next_state = INSTR_CTRL;
        end
      end

      INSTR_CTRL : begin
        mdio_oen = 1;
        if (bit_idx == 0) begin
          reg_wr_p = 1;
          incr_ip = 1;
          shift_reg_p = rom[ip];
          next_state = INSTR_WRITE; // TODO read
        end
      end

      INSTR_WRITE : begin
        mdio_oen = 1;
        if (bit_idx == 0)
          next_state = (ip == ROM_SIZE) ? HALT :IDLE;
      end
    endcase
  end

endmodule : mdio_driver
