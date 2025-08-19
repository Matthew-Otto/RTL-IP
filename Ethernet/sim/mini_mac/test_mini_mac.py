import os
import random
import sys
import time

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock

lib_path = "../"
sys.path.insert(0, lib_path)
import convert_8b10b


@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    print("DUT reset")

@cocotb.coroutine
async def serdes_driver(dut, symbols):
    for sym in symbols:
        dut.rx_data.value = sym
        await RisingEdge(dut.rx_clk)

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


@cocotb.test()
async def rx_test(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 8000, units="ps").start())
    await Timer(2.5, units="ns")
    cocotb.start_soon(Clock(dut.rx_clk, 7950, units="ps").start())
    await reset(dut)

    data = [0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50, 0xfb]
    ctrl = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]
    data.extend([0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5])
    ctrl.extend([0, 0, 0, 0, 0, 0, 0, 0])
    data.extend([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x0, 0x7, 0xed, 0x12, 0x34, 
                 0x56, 0x8, 0x0, 0x9f, 0x42, 0xc6, 0xa6, 0xc9, 0xc4, 0x77, 0x32, 
                 0x16, 0x42, 0x76, 0x74, 0x67, 0x93, 0xe5, 0x6, 0xd0, 0x3, 0x29, 
                 0xde, 0x3a, 0xb9, 0xc2, 0x23, 0x32, 0xcd, 0xad, 0xf2, 0x4b, 0x13, 
                 0x74, 0xcc, 0xb2, 0xde, 0x40, 0x20, 0xbb, 0x2a, 0xa7, 0xb4, 0x45, 
                 0x78, 0xb8, 0xd0, 0x41, 0xba, 0x9, 0x50, 0x40, 0x13, 0x6e, 0x8d, 
                 0x69, 0xcd, 0xe0, 0x29, 0x7f, 0x31, 0x70, 0xf8, 0x90, 0x0, 0x6d, 
                 0xcd, 0xcd, 0xaa, 0xa9, 0x81])
    ctrl.extend([0] * (len(data) - len(ctrl)))
    data.extend([0xfd, 0xf7, 0xf7, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50])
    ctrl.extend([1, 1, 1, 1, 0, 1, 0, 1, 0])

    data *= 2
    ctrl *= 2

    code_groups = convert_8b10b.encode(data, ctrl)
    
    cocotb.start_soon(serdes_driver(dut,code_groups))

    for _ in range(400):
        await FallingEdge(dut.clk)
        dut.ready_out.value = dut.ready_in.value
        dut.valid_in.value = dut.valid_out.value
        dut.data_in.value = dut.data_out.value
        dut.eof_in.value = dut.eof_out.value
        await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 100)


@cocotb.test()
async def rx_test_lose_sync(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 8, units="ns").start())
    await Timer(2.5, units="ns")
    cocotb.start_soon(Clock(dut.rx_clk, 7950, units="ps").start())
    await reset(dut)

    data = [0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50, 0xfb]
    ctrl = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]
    data.extend([0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5])
    ctrl.extend([0, 0, 0, 0, 0, 0, 0, 0])
    data.extend([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x0, 0x7, 0xed, 0x12, 0x34, 
                 0x56, 0x8, 0x0, 0x9f, 0x42, 0xc6, 0xa6, 0xc9, 0xc4, 0x77, 0x32, 
                 0x16, 0x42, 0x76, 0x74, 0x67, 0x93, 0xe5, 0x6, 0xd0, 0x3, 0x29, 
                 0xde, 0x3a, 0xb9, 0xc2, 0x23, 0x32, 0xcd, 0xad, 0xf2, 0x4b, 0x13, 
                 0x74, 0xcc, 0xb2, 0xde, 0x40, 0x20, 0xbb, 0x2a, 0xa7, 0xb4, 0x45, 
                 0x78, 0xb8, 0xd0, 0x41, 0xba, 0x9, 0x50, 0x40, 0x13, 0x6e, 0x8d, 
                 0x69, 0xcd, 0xe0, 0x29, 0x7f, 0x31, 0x70, 0xf8, 0x90, 0x0, 0x6d, 
                 0xcd, 0xcd, 0xaa, 0xa9, 0x81])
    ctrl.extend([0] * (len(data) - len(ctrl)))
    data.extend([0xfd, 0xf7, 0xf7, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50])
    ctrl.extend([1, 1, 1, 1, 0, 1, 0, 1, 0])


    data = data[:40]
    ctrl = ctrl[:40]
    data.extend([0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50, 0xbc, 0x50])
    ctrl.extend([0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0])

    code_groups = convert_8b10b.encode(data, ctrl)
    
    cocotb.start_soon(serdes_driver(dut,code_groups))

    for _ in range(400):
        await FallingEdge(dut.clk)
        dut.ready_out.value = dut.ready_in.value
        dut.valid_in.value = dut.valid_out.value
        dut.data_in.value = dut.data_out.value
        dut.eof_in.value = dut.eof_out.value
        await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 10000)


#@cocotb.test()
async def tx_test(dut):
    seed = 12345 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 8, units="ns").start())
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

    cocotb.start_soon(Clock(dut.clk, 8, units="ns").start())
    await reset(dut)

    symbols = [0x0fa, 0x2aa, 0x18b, 0x18b, 0x305, 0x2d5, 0x18b, 0x18b, 0x305, 0x2aa, 0x274, 0x274, 0x0fa, 0x125, 0x274, 0x274, 0x0fa, 0x2aa, 0x18b, 0x18b, 0x305, 0x2d5, 0x18b, 0x18b, 0x305, 0x2aa, 0x274, 0x274]
    cocotb.start_soon(serdes_emulator(dut,symbols))
    await ClockCycles(dut.clk, 100)