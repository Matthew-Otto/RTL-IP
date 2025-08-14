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

@cocotb.test()
async def test(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset(dut)

    test_data = [
        '0101010101', '1010101010', 
        '1000001011', '0000010111', '0000101110', '0001011100', '0010111000', '0101110000', '1011100000', '0111000001', '1110000010', '1100000101',
        '0111110100', '1111101000', '1111010001', '1110100011', '1101000111', '1010001111', '0100011111', '1000111110', '0001111101', '0011111010',
        '0011111010', '0101010101', '0101010101', '0101010101', '0011111010', '0101010101', '0101010101', '0101010101', '1100000101', '0101010101']

    for word in test_data:
        dut.input_data.value = int(word,2)
        await RisingEdge(dut.clk)

