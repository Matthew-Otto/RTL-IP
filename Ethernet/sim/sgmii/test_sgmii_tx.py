import os
import random
import sys
import time
from queue import Queue

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock


@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.clk_125M)
    dut.reset.value = 1
    await ClockCycles(dut.clk_125M, 5)
    dut.reset.value = 0
    print("DUT reset")

@cocotb.test()
async def test(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    # start system clock
    cocotb.start_soon(Clock(dut.clk_125M, 20, units="ns").start())
    await reset(dut)

    await ClockCycles(dut.clk_125M, 7)

    dut.sof.value = 1
    dut.data.value = random.getrandbits(8)
    await RisingEdge(dut.clk_125M)
    dut.sof.value = 0
    for _ in range(38):
        dut.data.value = random.getrandbits(8)
        await RisingEdge(dut.clk_125M)
    dut.eof.value = 1
    dut.data.value = random.getrandbits(8)

    await ClockCycles(dut.clk_125M, 20)


   