import random
import time

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock


@cocotb.test()
async def random_stimulus(dut):
    seed = 1750901959 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    iters = 100000
    ptr = 0
    buffer = 0
    skid_buffer = 0
    valid = 0

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    
    for _ in range(iters):
        await FallingEdge(dut.clk)
        # set input valid
        if (valid and ready) or not valid:
            valid = random.randint(0, 1)
            dut.input_valid.value = valid
            if valid:
                data = random.randint(0,255)
                dut.input_data.value = data

        # set output ready
        dut.output_ready.value = random.randint(0, 1)

        # save ready value from before clock
        ready = dut.input_ready.value

        await RisingEdge(dut.clk)

        if dut.output_ready.value and dut.output_valid.value:
            assert dut.output_data.value == buffer, f"Sim buffer: {hex(dut.output_data.value)} does not match virt buffer: {hex(buffer)}"
            if dut.resume.value:
                buffer = skid_buffer
                ptr = 1
            else:
                buffer = 0
                ptr = 0

        if (valid and ready and ptr < 4):
            buffer += data << (8*ptr)
            ptr += 1
        if (valid and ready and ptr == 4):
            skid_buffer = data



