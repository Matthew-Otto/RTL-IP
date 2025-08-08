import os
import random
import sys
import time

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.axi import AxiLiteMasterWrite, AxiLiteMaster, AxiLiteSlave, AxiLiteSlaveRead
from cocotbext.axi import AxiLiteWriteBus, AxiLiteReadBus, AxiLiteBus, AxiLiteRamRead, AxiLiteRamWrite


@cocotb.test()
async def test_control_port(dut):
    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    axi_master = AxiLiteMasterWrite(AxiLiteWriteBus.from_prefix(dut, "s_axi"), dut.clk, dut.reset)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    # reset
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)


    # write to invalid address
    write_op = axi_master.init_write(0x10, b'test')
    await write_op.wait()
    r = write_op.data
    print(f"Invalid write resp: {r.resp}")
    assert r.resp == 0x2, "Writing to invalid address did not produce correct error code"


    # write to valid address
    await axi_master.write_byte(0x1, 0x8)
    await RisingEdge(dut.clk)
    assert dut.registers[0] == 0x0800, "Invalid register data after valid write"

    await axi_master.write_word(0x2, 0x04fe)
    await RisingEdge(dut.clk)
    assert dut.registers[0] == 0x04fe0800, "Invalid register data after valid write"

    await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 20)
