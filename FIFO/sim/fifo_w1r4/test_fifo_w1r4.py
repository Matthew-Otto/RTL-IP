import random
import time
from queue import Queue

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink


async def reset(dut):
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    print("DUT reset")


async def write_data(dut, ref_fifo, iters):
    for _ in range(iters):
        if not dut.ready_in.value:
            await RisingEdge(dut.clk)
            continue

        if random.random() < 0.90:
            block = random.getrandbits(8)
            ref_fifo.put(block)
            dut.valid_in.value = 1
            dut.data_in.value = block
            dut._log.debug(f"{_} writing data >>{hex(block)}")
        else:
            dut.valid_in.value = 0

        await RisingEdge(dut.clk)
    dut.valid_in.value = 0



async def read_data(dut, ref_fifo, iters):
    no_valid_cnt = 0
    quad_buffer = []
    for _ in range(iters):
        await RisingEdge(dut.clk)

        while len(quad_buffer) < 4 and ref_fifo.qsize() > 0:
            quad_buffer.append(ref_fifo.get())

        if random.random() < 0.5:
            for i in range(4):
                if random.random() < 0.85:
                    dut.ready_out[i].value = 1
                else:
                    dut.ready_out[i].value = 0
        else:
            dut.ready_out.value = 0

        await ReadOnly()

        for i in range(4):               
            if not dut.ready_out[i].value or not dut.valid_out[i].value:
                continue

            block = dut.data_out[i].value
            dut._log.debug(f"{_} {i} reading data <<{hex(block)}")
            assert block in quad_buffer, f"Value {hex(block)} not in output buffer {[hex(x) for x in quad_buffer]}"
            quad_buffer.remove(block)
    
    await RisingEdge(dut.clk)
    dut.ready_out.value = 0



@cocotb.test()
async def test_read_write(dut):

    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")
    dut._log.setLevel("DEBUG")

    iters = 100000
    ref_fifo = Queue()

    cocotb.start_soon(Clock(dut.clk, 2, units="ps").start())
    await reset(dut)

    fifo_write = cocotb.start_soon(write_data(dut, ref_fifo, iters))
    fifo_read = cocotb.start_soon(read_data(dut, ref_fifo, iters))

    await fifo_write
    await fifo_read





