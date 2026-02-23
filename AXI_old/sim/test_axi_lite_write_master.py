import random

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.axi import AxiLiteMasterWrite, AxiLiteSlaveWrite
from cocotbext.axi import AxiLiteWriteBus, AxiLiteRamRead, AxiLiteRamWrite

@cocotb.test()
async def test_writes(dut):
    axi_slave_ram = AxiLiteRamWrite(AxiLiteWriteBus.from_prefix(dut, "m_axi"), dut.clk, dut.reset, size=100)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    dut.valid.value = 1
    dut.address.value = 0x0
    dut.data.value = 0xdeadbeef
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.valid.value = 0

    await ClockCycles(dut.clk, 5)

    dut.valid.value = 1
    dut.address.value = 0x4
    dut.data.value = 0xaa00aa00
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.address.value = 0x8
    dut.data.value = 0x55555555
    dut.valid.value = 0

    await ClockCycles(dut.clk, 5)

    axi_slave_ram.hexdump(0x0, 12, prefix="RAM")

    data = [0xef, 0xbe, 0xad, 0xde, 0x00, 0xaa, 0x00, 0xaa, 0x00, 0x00, 0x00, 0x00]
    for idx,b in enumerate(axi_slave_ram.mem[0:12]):
        assert b == data[idx], f"Invalid data in RAM"

    #axi_slave_ram.write_dword(0x0, 0xdeadbeef)
    #await ClockCycles(dut.clk, 5)


@cocotb.test()
async def test_addrb4data(dut):
    dut.m_axi_awready.value = 0
    dut.m_axi_wready.value = 0

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    dut.valid.value = 1
    dut.address.value = 0x0
    dut.data.value = 0xdeadbeef

    dut.m_axi_awready.value = 1
    await ClockCycles(dut.clk, 2)
    assert not dut.ready.value, "Interface asserted ready prematurely"

    dut.m_axi_wready.value = 1

    await ReadOnly()
    while not dut.ready.value:
        await ReadOnly()
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.valid.value = 0

    await ClockCycles(dut.clk, 5)


@cocotb.test()
async def test_datab4addr(dut):
    dut.m_axi_awready.value = 0
    dut.m_axi_wready.value = 0

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    dut.valid.value = 1
    dut.address.value = 0x0
    dut.data.value = 0xdeadbeef

    dut.m_axi_wready.value = 1
    await ClockCycles(dut.clk, 2)
    assert not dut.ready.value, "Interface asserted ready prematurely"

    dut.m_axi_awready.value = 1

    await ReadOnly()
    while not dut.ready.value:
        await ReadOnly()
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.valid.value = 0

    await ClockCycles(dut.clk, 5)


@cocotb.test()
async def test_errors(dut):
    axi_slave_ram = AxiLiteRamWrite(AxiLiteWriteBus.from_prefix(dut, "m_axi"), dut.clk, dut.reset, size=0x4)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    dut.valid.value = 1
    dut.address.value = 0x1000
    dut.data.value = 0xdeadbeef
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.valid.value = 0

    await ClockCycles(dut.clk, 3)
    dut.m_axi_bvalid.value = 1
    dut.m_axi_bresp.value = 2

    await ClockCycles(dut.clk, 5)
    assert dut.error.value, "Interface did not respond to write error"

    dut.reset.value = 1
    await ClockCycles(dut.clk, 1)
    dut.reset.value = 0

    dut.valid.value = 1
    dut.address.value = 0x0
    dut.data.value = 0xdeadbeef
    while not dut.ready.value:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.valid.value = 0

    data = [0xef, 0xbe, 0xad, 0xde]
    for idx,b in enumerate(axi_slave_ram.mem[0:4]):
        assert b == data[idx], f"Invalid data in RAM"



