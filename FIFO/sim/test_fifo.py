import random
from queue import Queue

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink


async def write_data(dut, ref_fifo, iters):
    for _ in range(iters):
        b = int.from_bytes(random.randbytes(1), 'big')
        ref_fifo.put(b)
        dut._log.debug(f"{_} writing data >>{hex(b)}")
        dut.data_in.value = b
        dut.valid_in.value = 1
        # wait one cycle after ready_in asserts
        while True:
            await FallingEdge(dut.clk)
            if dut.ready_in.value:
                break
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # deassert if waiting a random amount of cycles
        dut.valid_in.value = 0
        # wait a random number of cycles before pushing new data
        await ClockCycles(dut.clk, random.randint(0, 2))


async def read_data(dut, ref_fifo, iters):
    dut.ready_out.value = 1
    for _ in range(iters):
        dut.ready_out.value = 1

        # wait for fifo to have valid data
        while True:
            await ReadOnly()
            if dut.valid_out.value:
                break
            await RisingEdge(dut.clk)

        # read data
        b = dut.data_out.value
        dut._log.debug(f"{_} reading data <<{hex(b)}")
        ref = ref_fifo.get()
        assert b == ref, f"FIFO output invalid | read {hex(b)} : reference {hex(ref)}"

        # deassert if waiting a random amount of cycles
        await RisingEdge(dut.clk)
        dut.ready_out.value = 0
        # wait a random number of cycles before popping more data
        await ClockCycles(dut.clk, random.randint(0, 2))



@cocotb.test()
async def write_test(dut):
    ref_fifo = Queue()
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    while True:
        if dut.ready_in.value == 0:
            break
        b = int.from_bytes(random.randbytes(1), 'big')
        dut._log.debug(f"writing data {hex(b)}")
        ref_fifo.put(b)
        dut.data_in.value = b
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    dut.ready_out.value = 1
    while True:
        if dut.valid_out.value == 0:
            break
        b = dut.data_out.value
        ref = ref_fifo.get()
        dut._log.debug(f"reading data {hex(b)}")
        #assert b == ref, f"FIFO output invalid | read {hex(b)} : reference {hex(ref)}"
        await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 5)



#@cocotb.test()
async def random_stimulus(dut):
    iters = 100000
    ref_fifo = Queue()

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    fifo_write = cocotb.start_soon(write_data(dut, ref_fifo, iters))
    fifo_read = cocotb.start_soon(read_data(dut, ref_fifo, iters))

    await fifo_write
    await fifo_read
    #await Timer(1, 'us')

