import random
import time

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock


@cocotb.test()
async def random_stimulus(dut):
    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    iters = 100000
    buffer = 0
    last_buffer = 0
    data = 0
    valid = 1

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)


    valid_lc = 1
    dut.input_valid.value = valid_lc
    data = random.randint(0,1<<32)
    dut.input_data.value = data
    buffer = data
    last_buffer = buffer

    for _ in range(iters):
        ready_lc = dut.input_ready.value

        await RisingEdge(dut.clk)

        # random input
        if (ready_lc and valid_lc) or not valid_lc:
            valid_lc = random.randint(0, 1)
            dut.input_valid.value = valid_lc
            if valid_lc:
                while True:
                    data = random.randint(0,1<<32)
                    if data>>24: # if the top byte is 0x00, it will break this testbench
                        break
                dut.input_data.value = data

        dut.output_ready.value = random.randint(0, 1)

        # check output
        await FallingEdge(dut.clk)
        if not buffer and dut.buffer.value != last_buffer:
            buffer = dut.buffer.value
            last_buffer = buffer
        if dut.output_ready.value and dut.output_valid.value:
            slice = buffer & 0xff
            assert dut.output_data.value == slice, f"dut slice: {hex(dut.output_data.value)} does not match sim slice: {hex(slice)}"
            buffer = buffer >> 8



