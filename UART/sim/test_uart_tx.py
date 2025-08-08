import random

import cocotb
from cocotb.triggers import Timer, ReadOnly, RisingEdge, FallingEdge, ClockCycles
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink


async def read_tx(uart_sink, packet_cnt):
    tx_data = []
    uart_sink.clear()
    while len(tx_data) < packet_cnt:
        tx_data.append(int((await uart_sink.read())[0]))
    return tx_data

@cocotb.test()
async def uart_tx_test_dense(dut):
    uart_sink = UartSink(dut.tx, baud=115200, bits=8)

    payload = [0xde, 0xad, 0xbe, 0xef]

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    # reset
    dut.reset.value = 1
    await ClockCycles(dut.clk, 1, rising=True)
    dut.reset.value = 0
    await ClockCycles(dut.clk, 1, rising=True)
    
    # start uart read coroutine
    uart_read = cocotb.start_soon(read_tx(uart_sink, len(payload)))

    for b in payload:
        dut.data.value = b
        dut.valid.value = 1

        await ReadOnly()

        while not dut.ready.value:
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    dut.valid.value = 0

    await uart_read
    tx_data = uart_read.result()

    dut._log.info(f"payload is {payload}")
    dut._log.info(f"tx_data is {tx_data}")
    assert payload == tx_data, "transmitted data does not match payload"


@cocotb.test()
async def uart_tx_test_sparse(dut):
    uart_sink = UartSink(dut.tx, baud=115200, bits=8)

    payload = [0xba, 0xad, 0xfe, 0xed]

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    # reset
    dut.reset.value = 1
    await ClockCycles(dut.clk, 1, rising=True)
    dut.reset.value = 0
    await ClockCycles(dut.clk, 1, rising=True)

    # start uart read coroutine
    uart_read = cocotb.start_soon(read_tx(uart_sink, len(payload)))

    packet_time = (1/115200)*10*1e6
    for b in payload:
        rand =  random.uniform(0.5, 1.5)
        await Timer(int(packet_time * rand), 'us')
        await RisingEdge(dut.clk)
        
        dut.data.value = b
        dut.valid.value = 1
        await ReadOnly()
        while not dut.ready.value:
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.valid.value = 0

    dut.valid.value = 0

    await uart_read
    tx_data = uart_read.result()

    dut._log.info(f"payload is {payload}")
    dut._log.info(f"tx_data is {tx_data}")
    assert payload == tx_data, "transmitted data does not match payload"
