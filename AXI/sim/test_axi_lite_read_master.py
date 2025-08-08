import random

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.axi import AxiLiteMasterWrite, AxiLiteSlaveWrite
from cocotbext.axi import AxiLiteWriteBus, AxiLiteReadBus, AxiLiteRamRead, AxiLiteRamWrite

@cocotb.test()
async def test_reads(dut):
    axi_slave_ram = AxiLiteRamRead(AxiLiteReadBus.from_prefix(dut, "m_axi"), dut.clk, dut.reset, size=1<<32)

    axi_slave_ram.mem[0x22222200:0x222222ff] = random.randbytes(0xff)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    dut.addr_valid.value = 1
    dut.addr.value = 0x22222200
    while not dut.addr_ready.value:
        await FallingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.addr_valid.value = 0

    dut.data_ready.value = 1
    while not dut.data_valid.value:
        await FallingEdge(dut.clk)
    data = dut.data.value
    await RisingEdge(dut.clk)

    data = int(data).to_bytes(4, byteorder='little')
    for idx,b in enumerate(axi_slave_ram.mem[0x22222200:0x22222204]):
        assert b == data[idx], f"Invalid data read from RAM"



@cocotb.test()
async def test_errors(dut):
    axi_slave_ram = AxiLiteRamRead(AxiLiteReadBus.from_prefix(dut, "m_axi"), dut.clk, dut.reset, size=100)

    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    dut.addr_valid.value = 1
    dut.addr.value = 0x1000
    while not dut.addr_ready.value:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.addr_valid.value = 0

    await ClockCycles(dut.clk, 3)
    dut.m_axi_rvalid.value = 1
    dut.m_axi_rresp.value = 2

    await ClockCycles(dut.clk, 5)
    assert dut.error.value, "Interface did not respond to write error"

    dut.reset.value = 1
    await ClockCycles(dut.clk, 1)
    axi_slave_ram.mem[0x0:0x4] = b'\xDE\xAD\xBE\xEF'
    dut.reset.value = 0

    dut.addr_valid.value = 1
    dut.addr.value = 0x0
    while not dut.addr_ready.value:
        await FallingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.addr_valid.value = 0

    dut.data_ready.value = 1
    while not dut.data_valid.value:
        await FallingEdge(dut.clk)
    data = dut.data.value
    await RisingEdge(dut.clk)
    dut.data_ready.value = 0

    data = int(data).to_bytes(4, byteorder='little')
    for idx,b in enumerate(axi_slave_ram.mem[0:4]):
        assert b == data[idx], f"Invalid data read from RAM"



