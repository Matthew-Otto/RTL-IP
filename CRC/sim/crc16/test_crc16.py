import random

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink

# Add the parent directory to sys.path
import os
import sys
utils_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../python_utils/'))
sys.path.insert(0, utils_dir)
from crc16_gen import serial_order_crc16


@cocotb.test()
async def crc16_test1(dut):

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    test_data = random.randbytes(random.randint(1,25))

    print(test_data)
    ref_data = serial_order_crc16(test_data)
    test_data += ref_data
    print(test_data)

    dut.valid.value = 1
    for b in test_data:
        for i in range(8):
            bit = (b >> i) & 0x1
            #bit = (b >> (7-i)) & 0x1
            dut.data.value = bit
            await RisingEdge(dut.clk)
    dut.valid.value = 0

    await Timer(1, 'us')

    print(f"Computed CRC: " + hex(dut.crc.value))

    assert dut.crc_error.value == 0, f"CRC calculation incorrect"

