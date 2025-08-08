import os
import sys
import random
import time
utils_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../python_utils'))
sys.path.insert(0, utils_dir)
from packet_gen import generate_packet

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink


async def read_tx(uart_sink, byte_cnt):
    tx_data = []
    while len(tx_data) < byte_cnt:
        b = await uart_sink.read(1)
        tx_data.append(int(b[0]))
    return tx_data



#@cocotb.test()
async def test_soc1(dut):
    uart_source = UartSource(dut.urx, baud=115200, bits=8)
    uart_sink = UartSink(dut.utx, baud=115200, bits=8)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    # reset
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    
    data = generate_packet("WRITE_WORD", [0x4], [0x00, 0x10, 0x00, 0x00])
    await uart_source.write(data)

    data = generate_packet("WRITE_WORD", [0x8], [0x00, 0x20, 0x00, 0x00])
    await uart_source.write(data)

    data = generate_packet("WRITE_WORD", [0x0], [0x1, 0x2<<2, 0xff, 0x0])
    await uart_source.write(data)
    #await uart_source.wait()

    data = await read_tx(uart_sink, 1)
    print(f"resp data: {data}")
    data = await read_tx(uart_sink, 1)
    print(f"resp data: {data}")
    data = await read_tx(uart_sink, 1)
    print(f"resp data: {data}")


    data = generate_packet("READ_WORD", [0x0])
    await uart_source.write(data)
    await uart_source.wait()

    rdata = await read_tx(uart_sink, 1)
    rdata = await read_tx(uart_sink, 4)
    print(f"ctrl reg data: {rdata}")


    data = generate_packet("READ_WORD", [0x4])
    await uart_source.write(data)
    await uart_source.wait()

    rdata = await read_tx(uart_sink, 1)
    rdata = await read_tx(uart_sink, 4)
    print(f"ctrl reg data: {rdata}")


    data = generate_packet("READ_WORD", [0x8])
    await uart_source.write(data)
    await uart_source.wait()

    rdata = await read_tx(uart_sink, 1)
    rdata = await read_tx(uart_sink, 4)
    print(f"ctrl reg data: {rdata}")


@cocotb.test()
async def test_halfword_write(dut):
    uart_source = UartSource(dut.urx, baud=115200, bits=8)
    uart_sink = UartSink(dut.utx, baud=115200, bits=8)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    # reset
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    data = generate_packet("WRITE_WORD", [0x0], [0x1, 0x2<<2])
    await uart_source.write(data)

    data = generate_packet("WRITE_WORD", [0x4], [0x00, 0x10])
    await uart_source.write(data)

    data = generate_packet("WRITE_WORD", [0x8], [0x00, 0x20])
    await uart_source.write(data)


    data = await read_tx(uart_sink, 1)
    print(f"resp data: {data}")
    data = await read_tx(uart_sink, 1)
    print(f"resp data: {data}")
    data = await read_tx(uart_sink, 1)
    print(f"resp data: {data}")


    data = generate_packet("READ_WORD", [0x0])
    await uart_source.write(data)
    await uart_source.wait()

    rdata = await read_tx(uart_sink, 1)
    rdata = await read_tx(uart_sink, 4)
    print(f"ctrl reg data: {rdata}")


    data = generate_packet("READ_WORD", [0x4])
    await uart_source.write(data)
    await uart_source.wait()

    rdata = await read_tx(uart_sink, 1)
    rdata = await read_tx(uart_sink, 4)
    print(f"ctrl reg data: {rdata}")


    data = generate_packet("READ_WORD", [0x8])
    await uart_source.write(data)
    await uart_source.wait()

    rdata = await read_tx(uart_sink, 1)
    rdata = await read_tx(uart_sink, 4)
    print(f"ctrl reg data: {rdata}")