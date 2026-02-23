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
async def test_reads(dut):
    random.seed(-1)
    # init system
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    axi_master = AxiLiteMaster(AxiLiteBus.from_entity(dut.axi), dut.clk, dut.reset)
    await reset(dut.clk, dut.reset)

    test_data = [random.getrandbits(32) for _ in range(4)]

    # write some test data over axi
    for idx in range(4):
        await axi_master.write_dword(idx<<2, test_data[idx])

    # check values from core interface
    for idx in range(4):
        assert test_data[idx] == dut.core_o[idx].value, f"Core read at idx {idx} returned incorrect value"

    await ClockCycles(dut.clk, 1)

    # clear some bits from the core
    for idx in range(4):
        random_mask = random.getrandbits(32)
        dut.core_i[idx].value = random_mask
        test_data[idx] &= ~random_mask
        await RisingEdge(dut.clk)
        dut.core_i[idx].value = 0

    # read new values from AXI
    for idx in range(4):
        data = await axi_master.read_dword(idx<<2)
        assert data == test_data[idx], f"AXI read at idx {idx} didn't match data driven by core.\n{hex(data)} =/= {hex(test_data[idx])}"



def test_runner():
    module_name = "axi_lite_csr_rw"
    sim = get_runner("verilator")

    proj_path = Path(__file__).resolve().parent.parent
    sources = [proj_path / "axi_lite_if.sv"]
    sources += [proj_path / "axi_lite_csr_rw.sv"]
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