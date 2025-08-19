import asyncio
import random
from queue import Queue

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock

flag_done = asyncio.Event()

@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.clk_in)
    dut.reset.value = 1
    await ClockCycles(dut.clk_in, 5)
    dut.reset.value = 0
    print("DUT reset")


async def write_data(dut, ref_fifo, iters):
    for _ in range(iters):
        b = int.from_bytes(random.randbytes(1), 'big')
        ref_fifo.put(b)
        dut._log.debug(f"{_} writing data >>{hex(b)}")
        dut.data_in.value = b
        dut.valid_in.value = 1
        # wait one cycle after ready_in asserts
        while True:
            await FallingEdge(dut.clk_in)
            if dut.ready_in.value:
                break
            await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)

        # deassert if waiting a random amount of cycles
        dut.valid_in.value = 0
        # wait a random number of cycles before pushing new data
        await ClockCycles(dut.clk_in, random.randint(0, 2))


async def read_data(dut, ref_fifo, iters):
    dut.ready_out.value = 1
    for _ in range(iters):
        dut.ready_out.value = 1

        # wait for fifo to have valid data
        await FallingEdge(dut.clk_out)
        while not dut.valid_out.value:
            await FallingEdge(dut.clk_out)

        # read data
        b = dut.data_out.value
        dut._log.debug(f"{_} reading data <<{hex(b)}")
        assert ref_fifo.qsize() != 0, "ref fifo is empty?"
        ref = ref_fifo.get()
        assert b == ref, f"FIFO output invalid | read {hex(b)} : reference {hex(ref)}"

        # deassert if waiting a random amount of cycles
        await RisingEdge(dut.clk_out)
        dut.ready_out.value = 0
        # wait a random number of cycles before popping more data
        await ClockCycles(dut.clk_out, random.randint(0, 2))




@cocotb.test()
async def random_stimulus(dut):
    iters = 100000
    ref_fifo = Queue()
    #dut._log.setLevel("DEBUG")

    # start system clock
    cocotb.start_soon(Clock(dut.clk_in, 7, units="ns").start())
    cocotb.start_soon(Clock(dut.clk_out, 13, units="ns").start())
    await reset(dut)

    iters = 1000000
    fifo_write = cocotb.start_soon(write_data(dut, ref_fifo, iters))
    fifo_read = cocotb.start_soon(read_data(dut, ref_fifo, iters))

    await fifo_write
    await fifo_read
    #await Timer(1, 'us')

