#!/usr/bin/env python3

from pathlib import Path
import os
import random

import cocotb
from cocotb_tools.runner import get_runner
from cocotb.clock import Clock
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotbext.axi import AxiLiteMaster,AxiLiteMasterWrite,AxiLiteMasterRead, AxiLiteSlaveWrite
from cocotbext.axi import AxiLiteBus, AxiLiteWriteBus, AxiLiteReadBus, AxiLiteRamRead, AxiLiteRamWrite
from cocotbext.uart import UartSource, UartSink


async def reset(clk, rst):
    await RisingEdge(clk)
    rst.value = 1
    await ClockCycles(clk, 5)
    rst.value = 0
    print("DUT reset")


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

    # init system
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut.clk, dut.reset)

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

    # init system
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut.clk, dut.reset)

    # start uart read coroutine
    uart_read = cocotb.start_soon(read_tx(uart_sink, len(payload)))

    packet_time = (1/115200)*10e6
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


def test_runner():
    module_name = "uart_tx"
    sim = get_runner("verilator")
    
    proj_path = Path(__file__).resolve().parent.parent
    sources = [proj_path / "uart_tx.sv"]

    sim.build(
        sources=sources,
        hdl_toplevel=module_name,
        always=False,
        waves=True,
        build_args=[
            "-Wno-SELRANGE",
            "-Wno-WIDTH",
            "--trace-fst",
            "--trace-structs",
        ]
    )

    sim.test(
        hdl_toplevel=module_name,
        test_module=Path(__file__).stem,
        waves=True,
        gui=True
    )

if __name__ == "__main__":
    test_runner()