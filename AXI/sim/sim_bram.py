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


async def reset(clk, rst):
    await RisingEdge(clk)
    rst.value = 1
    await ClockCycles(clk, 5)
    rst.value = 0
    print("DUT reset")


@cocotb.test()
async def test_axi_bram(dut):
    random.seed(-1)
    # init system
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    axi_master = AxiLiteMaster(AxiLiteBus.from_entity(dut.axi), dut.clk, dut.reset)
    await reset(dut.clk, dut.reset)

    test_data = [random.getrandbits(32) for _ in range(1024//4)]

    # test single write/read
    await axi_master.write_dword(0x0, test_data[0])
    await axi_master.write_dword(0x4, test_data[1])
    data = await axi_master.read_dword(0x0)
    assert data == test_data[0], f"AXI single read/write failed at address 0x0"
    data = await axi_master.read_dword(0x4)
    assert data == test_data[1], f"AXI single read/write failed at address 0x4"

    # test cocotb-ext burst write/read
    write_tasks = []
    for idx in range(2, 10):
        task = cocotb.start_soon(axi_master.write_dword(idx<<2, test_data[idx]))
        write_tasks.append(task)
    for task in write_tasks:
        await task

    await ClockCycles(dut.clk, 2)

    for idx in range(2, 10):
        data = await axi_master.read_dword(idx<<2)
        assert data == test_data[idx], f"AXI burst read/write failed at address 0x{idx<<2:x}"


    # test byte sel
    test_data = {}
    for idx in range(100,120):
        addr = idx<<2
        data = random.getrandbits(32)
        test_data[addr] = data
        await axi_master.write_dword(addr, data)

    await ClockCycles(dut.clk, 2)

    for idx in range(100,120):
        addr = idx<<2
        data = random.getrandbits(8)
        test_data[addr] = (test_data[addr] & 0xffffff00) | data
        await axi_master.write_byte(addr, data)

    for addr,data in test_data.items():
        read_data = await axi_master.read_dword(addr)
        assert data == read_data, f"AXI byte enable read/write failed at addres 0x{addr}"
    

    await ClockCycles(dut.clk, 50)



def test_runner():
    module_name = "axi_lite_bram"
    sim = get_runner("verilator")
    
    proj_path = Path(__file__).resolve().parent.parent
    sources = [proj_path / "axi_lite_if.sv"]
    sources += [proj_path / "axi_lite_bram.sv"]
    sources += ["wrapper_template.sv"]

    sim.build(
        sources=sources,
        hdl_toplevel="wrapper_template",
        always=False,
        waves=True,
        build_args=[
            "-Wno-SELRANGE",
            "-Wno-WIDTH",
            "--trace-fst",
            "--trace-structs",
            f"-DINTF_TYPE=axi_lite_if",
            f"-DDUT_NAME={module_name}",
        ]
    )

    sim.test(
        hdl_toplevel="wrapper_template",
        test_module=Path(__file__).stem,
        waves=True,
        gui=True
    )

if __name__ == "__main__":
    test_runner()