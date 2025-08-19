// drives preconfigured values onto MDIO bus and reads back the results

module mdio_driver (
  input  logic clk,
  input  logic reset,

  // (fast) clk domain
  output logic read_burst,
  output logic [4:0] read_addr,
  output logic [15:0] read_data,

  // slow clock domain
  output logic enet_mdc,
  inout  logic enet_mdio
);

  localparam ROM_SIZE = 8;
  localparam ROM_ADDR = $clog2(ROM_SIZE);

  logic [15:0] rom [ROM_SIZE-1:0];

  initial begin
    // select page 1
    rom[0] = 16'b01_01_00000_10110_10;
    rom[1] = 16'b0100_0000_0000_0001;
    // disable SGMII autoneg
    rom[2] = 16'b01_01_00000_00000_10;
    rom[3] = 16'b0000_0001_0100_0000;
    // select page 0
    rom[4] = 16'b01_01_00000_10110_10;
    rom[5] = 16'b0000_0000_0000_0000;
    // disable copper autoneg and reset
    rom[6] = 16'b01_01_00000_00000_10;
    rom[7] = 16'b1000_0001_0100_0000;
  end

  // clock divider
  logic slow_clk;
  logic [4:0] cnt;
  always_ff @(posedge clk) begin
    if (reset || (cnt == 5'd24)) 
      cnt <= 0;
    else
      cnt <= cnt + 1;

    if (cnt == 5'd24)
      slow_clk <= ~slow_clk;
  end
  assign enet_mdc = slow_clk;

  // reset timer
  logic        slow_reset;
  logic [14:0] reset_timer;
  always_ff @(posedge slow_clk or posedge reset) begin
    if (reset)
      reset_timer <= 15'd25000;
    else if (|reset_timer)
      reset_timer <= reset_timer - 1;
  end
  assign slow_reset = |reset_timer;

  // shift register
  logic mdio_in;
  logic mdio_ien;
  logic mdio_out;
  logic mdio_oen;

  logic reg_wr_p;
  logic reg_r_p;
  logic [15:0] shift_reg;
  logic [15:0] shift_reg_p;

  assign mdio_out = shift_reg[15];

  assign mdio_in = mdio_ien ? enet_mdio : 1'b0;
  assign enet_mdio = mdio_oen ? mdio_out : 1'bz;

  always_ff @(posedge slow_clk) begin
    for (int i = 0; i < 16; i++) begin
      if (i == 0) begin
        if (slow_reset)
          shift_reg[i] <= 1'b0;
        else
          shift_reg[i] <= reg_wr_p ? shift_reg_p[i] : mdio_in;
      end else begin
        if (slow_reset)
          shift_reg[i] <= 1'b0;
        else
          shift_reg[i] <= reg_wr_p ? shift_reg_p[i] : shift_reg[i-1];
      end
    end
  end


  // state machine
  logic              incr_ip;
  logic [ROM_ADDR:0] ip;
  logic [3:0]        bit_idx;


  enum {
    IDLE,
    PREAMBLE_H1,
    PREAMBLE_H2,
    INSTR_CTRL_W,
    INSTR_WRITE,
    INSTR_CTRL_R,
    INSTR_READ,
    WAIT,
    HALT
  } state, next_state;

  always_ff @(posedge slow_clk) begin
    if (slow_reset) state <= IDLE;
    else       state <= next_state;

    if (slow_reset) ip <= 0;
    else if (incr_ip) ip <= ip + 1;

    if (reg_wr_p) bit_idx <= 4'hf;
    else bit_idx <= bit_idx - 1;
  end

  always_comb begin
    next_state = state;
    reg_wr_p = 0;
    reg_r_p = 0;
    shift_reg_p = 0;
    incr_ip = 0;
    mdio_ien = 0;
    mdio_oen = 0;

    case (state)
      IDLE : begin
        if (ip == ROM_SIZE) begin
          next_state = HALT;
        end else if (rom[ip] == 16'hffff) begin
          next_state = WAIT;
        end else begin
          shift_reg_p = 16'hFFFF;
          reg_wr_p = 1;
          next_state = PREAMBLE_H1;
        end
      end

      PREAMBLE_H1 : begin
        mdio_oen = 1;
        if (bit_idx == 0) begin
          shift_reg_p = 16'hFFFF;
          reg_wr_p = 1;
          next_state = PREAMBLE_H2;
        end
      end
      PREAMBLE_H2 : begin
        mdio_oen = 1;
        if (bit_idx == 0) begin
          shift_reg_p = rom[ip];
          reg_wr_p = 1;
          incr_ip = 1;
          next_state = (rom[ip][13:12] == 2'b01) ? INSTR_CTRL_W : INSTR_CTRL_R;
        end
      end

      INSTR_CTRL_W : begin
        mdio_oen = 1;
        if (bit_idx == 0) begin
          shift_reg_p = rom[ip];
          reg_wr_p = 1;
          incr_ip = 1;
          next_state = INSTR_WRITE;
        end
      end
      
      INSTR_WRITE : begin
        mdio_oen = 1;
        if (bit_idx == 0)
          next_state = IDLE;
      end

      INSTR_CTRL_R : begin
        mdio_oen = |bit_idx[3:1]; // deassert bus driver on last two cycles
        if (bit_idx == 0) begin
          next_state = INSTR_READ;
        end
      end

      INSTR_READ : begin
        mdio_ien = 1;
        if (bit_idx == 0) begin
          reg_r_p = 1;
          next_state = IDLE;
        end
      end

      WAIT : begin
        if (bit_idx == 0) begin
          incr_ip = 1;
          next_state = IDLE;
        end
      end
    endcase
  end

  // read buffer
  logic [15:0] read_buffer [31:0];

  logic [4:0] buffer_wr_addr;
  logic buffer_wr_latch;

  always_ff @(posedge slow_clk) begin
    if ((state == PREAMBLE_H2) && reg_wr_p)
      buffer_wr_addr <= rom[ip][6:2];

    buffer_wr_latch <= reg_r_p;

    if (slow_reset)
      for (int i = 0; i < 16; i++)
        read_buffer[i] <= 0;
    else if (buffer_wr_latch)
      read_buffer[buffer_wr_addr] <= shift_reg;
  end

  enum {
    READ_IDLE,
    READ_BURST,
    READ_HALT
  } read_burst_state;

  always_ff @(posedge clk) begin
    if (reset)
      read_burst_state <= READ_IDLE;
    else begin
      case (read_burst_state)
        READ_IDLE : begin
          if (state == HALT) begin
            read_burst_state <= READ_BURST;
            read_addr <= 0;
            read_burst <= 1;
          end
        end

        READ_BURST : begin
          if (read_addr == 5'h1f) begin
            read_burst_state <= READ_HALT;
            read_burst <= 0;
          end else begin
            read_addr <= read_addr + 1;
          end
        end
      endcase
    end
  end

  assign read_data = read_buffer[read_addr];

endmodule : mdio_driver
