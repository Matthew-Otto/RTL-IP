import os
import random
import sys
import time

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


@cocotb.test()
async def test_crc32(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset(dut)

    frame = [255, 255, 255, 255, 255, 255, 0, 7, 237, 46, 5, 19, 8, 0, 119, 21, 108, 250, 
             93, 81, 24, 152, 35, 159, 176, 217, 163, 70, 117, 74, 127, 1, 4, 190, 105, 
             140, 157, 206, 43, 140, 67, 97, 252, 254, 233, 173, 193, 14, 109, 133, 68, 
             20, 138, 86, 91, 127, 148, 238, 117, 16, 252, 22, 106, 51, 67, 238, 179, 149, 
             97, 227, 136, 6, 32, 82, 139, 250, 236, 60, 140, 0, 244, 169]
    
    #frame = [0x1, 0x2, 0x3 4 5 6 7 8 9]

    for b in frame:
        dut.data_valid.value = 1
        dut.data_in.value = b
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    dut.data_in.value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 5)
