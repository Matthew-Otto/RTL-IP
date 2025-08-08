import asyncio
import random
from queue import Queue
import os

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink

iters = 200000
fifo_size = 32
flag_done = asyncio.Event()

async def write_data(dut, ref_fifo):
    dut.commit.value = 1
    dut.revert.value = 0
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


async def spec_write_data(dut, ref_fifo):
    spec_fifo = Queue()
    uncommitted_cnt = 0

    for _ in range(iters):
        # push data randomly
        if random.random() > (1/3):
            b = int.from_bytes(random.randbytes(1), 'big')
            dut._log.debug(f"{_} writing data >>{hex(b)}")
            dut.data_in.value = b
            dut.valid_in.value = 1
            spec_fifo.put(b)
            uncommitted_cnt += 1

        # commit / revert randomly
        dut.commit.value = 0
        dut.revert.value = 0
        if random.random() < (uncommitted_cnt/fifo_size):
            dut.commit.value = 1
            uncommitted_cnt = 0
            while not spec_fifo.empty():
                ref_fifo.put(spec_fifo.get())
        elif random.random() < (uncommitted_cnt/fifo_size):
            dut.revert.value = 1
            uncommitted_cnt = 0
            while not spec_fifo.empty():
                spec_fifo.get()

        # wait one cycle after ready_in asserts
        while True:
            await FallingEdge(dut.clk)
            if dut.ready_in.value:
                break
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        # deassert valid
        dut.valid_in.value = 0
    flag_done.set()


async def read_data(dut, ref_fifo):
    dut.ready_out.value = 1
    for _ in range(iters):
        if flag_done.is_set() and ref_fifo.empty():
            break

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
async def fifo_test1(dut):
    ref_fifo = Queue()

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    fifo_write = cocotb.start_soon(write_data(dut, ref_fifo))
    fifo_read = cocotb.start_soon(read_data(dut, ref_fifo))

    await fifo_write
    await fifo_read
    #await Timer(1, 'us')


@cocotb.test()
async def fifo_test2(dut):
    ref_fifo = Queue()

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    fifo_write = cocotb.start_soon(spec_write_data(dut, ref_fifo))
    fifo_read = cocotb.start_soon(read_data(dut, ref_fifo))

    await fifo_write
    await fifo_read
    #await Timer(1, 'us')