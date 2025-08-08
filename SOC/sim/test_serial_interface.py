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


async def read_tx(uart_sink, packet_cnt):
    tx_data = []
    uart_sink.clear()
    while len(tx_data) < packet_cnt:
        tx_data.append(int((await uart_sink.read())[0]))
    return tx_data


@cocotb.test()
async def test_DMA_ctrl(dut):
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

    uart_read = cocotb.start_soon(read_tx(uart_sink, 1))

    data = generate_packet("W_BUFFER", [0x0], [0xde, 0xad, 0xbe, 0xef])

    print(f"full packet: {data}")

    await uart_source.write(data)
    await uart_source.wait()

    

    await uart_read
    resp = uart_read.result()

    dut._log.info(f"resp is {resp}")
    assert resp == [0x6], "did not receive ack"

