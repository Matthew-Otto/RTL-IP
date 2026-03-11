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


async def test_write(test_data, master):
    write_tasks = []
    for idx,data in enumerate(test_data):
        task = cocotb.start_soon(master.write_dword(idx<<2, data))
        write_tasks.append(task)
    for task in write_tasks:
        await task


async def test_read(test_data, master):
    for idx,data in enumerate(test_data):
        read_data = await master.read_dword(idx<<2)
        assert data == read_data, f"AXI read/write failed at address 0x{idx<<2:x}"


@cocotb.test()
async def test_axi_bram(dut):
    random.seed(-1)
    # init system
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    axi_master_a = AxiLiteMaster(AxiLiteBus.from_entity(dut.axi_a), dut.clk, dut.reset)
    axi_master_b = AxiLiteMaster(AxiLiteBus.from_entity(dut.axi_b), dut.clk, dut.reset)
    await reset(dut.clk, dut.reset)


    # test port A cocotb-ext burst write/read
    test_data = [random.getrandbits(32) for _ in range(1024//4)]
    await test_write(test_data, axi_master_a)
    await ClockCycles(dut.clk, 2)
    await test_read(test_data, axi_master_a)


    await ClockCycles(dut.clk, 10)

    # test port B cocotb-ext burst write/read
    test_data = [random.getrandbits(32) for _ in range(1024//4)]
    await test_write(test_data, axi_master_b)
    await ClockCycles(dut.clk, 2)
    await test_read(test_data, axi_master_b)


    # burst both simultaneously
    test_data_a = [random.getrandbits(32) for _ in range(1024//4)]
    test_data_b = [random.getrandbits(32) for _ in range(1024//4)]
    ta = cocotb.start_soon(test_write(test_data_a, axi_master_a))
    tb = cocotb.start_soon(test_write(test_data_b, axi_master_b))
    await ta
    await tb

    await ClockCycles(dut.clk, 2)
    await test_read(test_data_b, axi_master_a)
    await test_read(test_data_b, axi_master_b)

    # test byte select


    # test byte sel
    # test_data = {}
    # for idx in range(100,120):
    #     addr = idx<<2
    #     data = random.getrandbits(32)
    #     test_data[addr] = data
    #     await axi_master.write_dword(addr, data)

    # await ClockCycles(dut.clk, 2)

    # for idx in range(100,120):
    #     addr = idx<<2
    #     data = random.getrandbits(8)
    #     test_data[addr] = (test_data[addr] & 0xffffff00) | data
    #     await axi_master.write_byte(addr, data)

    # for addr,data in test_data.items():
    #     read_data = await axi_master.read_dword(addr)
    #     assert data == read_data, f"AXI byte enable read/write failed at addres 0x{addr}"
    

    await ClockCycles(dut.clk, 50)



def test_runner():
    module_name = "axi_lite_bram_dualport"
    sim = get_runner("verilator")
    
    proj_path = Path(__file__).resolve().parent.parent
    sources = [proj_path / "axi_lite_if.sv"]
    sources += [proj_path / "axi_lite_bram_dualport.sv"]
    sources += ["wrapper_template_dual.sv"]

    sim.build(
        sources=sources,
        hdl_toplevel="wrapper_template_dual",
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
        hdl_toplevel="wrapper_template_dual",
        test_module=Path(__file__).stem,
        waves=True,
        gui=True
    )

if __name__ == "__main__":
    test_runner()