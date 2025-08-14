import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock


@cocotb.test()
async def reset_test(dut):
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())

    await RisingEdge(dut.clk)
    await Timer(33, 'ns')
    dut.async_reset.value = 1
    await ClockCycles(dut.clk, 3)
    await Timer(75, 'ns')
    dut.async_reset.value = 0
    await ClockCycles(dut.clk, 5)

