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
async def test_stream(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    await reset(dut)

    frame = [255, 255, 255, 255, 255, 255, 0, 7, 237, 46, 5, 19, 8, 0, 119, 21, 108, 250, 
             93, 81, 24, 152, 35, 159, 176, 217, 163, 70, 117, 74, 127, 1, 4, 190, 105, 
             140, 157, 206, 43, 140, 67, 97, 252, 254, 233, 173, 193, 14, 109, 133, 68, 
             20, 138, 86, 91, 127, 148, 238, 117, 16, 252, 22, 106, 51, 67, 238, 179, 149, 
             97, 227, 136, 6, 32, 82, 139, 250, 236, 60, 140, 0, 244, 169]

    for b in frame:
        dut.data_valid.value = 1
        dut.data_in.value = b
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    dut.data_in.value = 0
    dut.eof.value = 1
    await RisingEdge(dut.clk)
    dut.eof.value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 5)


@cocotb.test()
async def test_random_valid(dut):
    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    await reset(dut)

    frame = [255, 255, 255, 255, 255, 255, 0, 7, 237, 46, 5, 19, 8, 0, 119, 21, 108, 250, 
             93, 81, 24, 152, 35, 159, 176, 217, 163, 70, 117, 74, 127, 1, 4, 190, 105, 
             140, 157, 206, 43, 140, 67, 97, 252, 254, 233, 173, 193, 14, 109, 133, 68, 
             20, 138, 86, 91, 127, 148, 238, 117, 16, 252, 22, 106, 51, 67, 238, 179, 149, 
             97, 227, 136, 6, 32, 82, 139, 250, 236, 60, 140, 0, 244, 169]

    for b in frame:
        dut.data_valid.value = 1
        dut.data_in.value = b
        await RisingEdge(dut.clk)
        while random.random() < (1/3):
            dut.data_valid.value = 0
            await RisingEdge(dut.clk)

    dut.data_valid.value = 0
    dut.data_in.value = 0
    dut.eof.value = 1
    await RisingEdge(dut.clk)
    crc_val = dut.fcs_good.value

    dut.eof.value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 5)

    assert crc_val, "Computed bad CRC value"