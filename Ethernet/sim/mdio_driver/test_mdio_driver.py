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
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    print("DUT reset")

@cocotb.coroutine
async def random_read(dut):
    while True:
        await RisingEdge(dut.enet_mdc)
        if dut.state.value == 6:
            dut.mdio_in.value = random.getrandbits(1)
        else:
            dut.mdio_in.value = 0


@cocotb.test()
async def test(dut):
    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    cocotb.start_soon(random_read(dut))
    await reset(dut)

    await ClockCycles(dut.clk, 4000)
    await reset(dut)
    await ClockCycles(dut.clk, 150)
    await reset(dut)
    await ClockCycles(dut.clk, 100000)


   