import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock



@cocotb.test()
async def debounce_test(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    await Timer(7, 'ns')
    dut.db_in.value = 1
    await Timer(13, 'ms')
    dut.db_in.value = 0
    await Timer(5, 'ms')

