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
async def serdes_emulator(dut, symbols):
    raw_bits = "".join([format(n, '010b') for n in symbols])

    i = 0
    while True:
        if i+10 <= len(raw_bits):
            symbol = raw_bits[i:i+10]
        else:
            print(raw_bits)
            d = len(raw_bits) - i
            print(f"len rawbits: {len(raw_bits)}")
            print(f"i: {i}")
            print(f"d: {d}")
            print(f"i+d: {i+d}")
            print(f"first: {raw_bits[i:i+d]}")
            print(f"second: {raw_bits[0:10-d]}")
            symbol = raw_bits[i:i+d] + raw_bits[0:10-d]
        print(f"Driving symbol {symbol}")
        dut.rx_data.value = int(symbol, 2)

        # BOZO bit slip is currently broken
        await FallingEdge(dut.clk)
        if dut.rx_bitslip.value:
            i += 11
        else:
            i += 10
        if i >= len(raw_bits):
            i = i - len(raw_bits)
        await RisingEdge(dut.clk)

@cocotb.coroutine
async def send_frame(dut, frame):
    for b in frame[:-1]:
        dut.valid_in.value = 1
        while dut.pause_in.value:
            await RisingEdge(dut.clk)
        dut.data_in.value = b
        await RisingEdge(dut.clk)

    dut.valid_in.value = 1
    while dut.pause_in.value:
        await RisingEdge(dut.clk)
    dut.eof_in.value = 1
    dut.data_in.value = frame[-1]
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.eof_in.value = 0


#@cocotb.test()
async def rx_test(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset(dut)

    symbols = [0x0fa, 0x2aa, 0x18b, 0x18b, 0x305, 0x2d5, 0x18b, 0x18b, 0x305, 0x2aa, 0x274, 0x274, 0x0fa, 0x125, 0x274, 0x274, 0x0fa, 0x2aa, 0x18b, 0x18b, 0x305, 0x2d5, 0x18b, 0x18b, 0x305, 0x2aa, 0x274, 0x274]
    cocotb.start_soon(serdes_emulator(dut,symbols))

    await ClockCycles(dut.clk, 100)


@cocotb.test()
async def tx_test(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset(dut)

    await ClockCycles(dut.clk, 7)

    await send_frame(dut, random.randbytes(64))
    await send_frame(dut, random.randbytes(64))

    await ClockCycles(dut.clk, 20)


#@cocotb.test()
async def autoneg_test(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset(dut)

    symbols = [0x0fa, 0x2aa, 0x18b, 0x18b, 0x305, 0x2d5, 0x18b, 0x18b, 0x305, 0x2aa, 0x274, 0x274, 0x0fa, 0x125, 0x274, 0x274, 0x0fa, 0x2aa, 0x18b, 0x18b, 0x305, 0x2d5, 0x18b, 0x18b, 0x305, 0x2aa, 0x274, 0x274]
    cocotb.start_soon(serdes_emulator(dut,symbols))
    await ClockCycles(dut.clk, 100)