import os
import random
import sys
import time

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.axi import AxiLiteMaster, AxiLiteBus
from cocotbext.axi import AxiRam, AxiBus


#@cocotb.test()
async def test_control_port(dut):
    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    axi_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi"), dut.clk, dut.reset)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    # reset
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)


    await axi_master.write_byte(0x1, 0x2<<2)
    await axi_master.write_word(0x2, 0x4)
    await axi_master.write_dword(0x8, 0xd099f00d)
    await axi_master.write_dword(0x4, 0xdeadbeef)

    data = await axi_master.read(0x0, 4)
    data = int.from_bytes(data.data, byteorder="little")
    print(f"data: {hex(data)}")
    assert data == 0x00040800, "Invalid control data"

    data = await axi_master.read(0x4, 4)
    data = int.from_bytes(data.data, byteorder="little")
    print(f"data: {hex(data)}")
    assert data == 0xdeadbeef, "Invalid src data"

    data = await axi_master.read(0x8, 4)
    data = int.from_bytes(data.data, byteorder="little")
    print(f"data: {hex(data)}")
    assert data == 0xd099f00d, "Invalid dest data"

    # start transfer
    await axi_master.write_byte(0x0, 0x1)

    data = await axi_master.read(0x0, 4)
    data = int.from_bytes(data.data, byteorder="little")
    print(f"data: {hex(data)}")
    assert data == 0x00040900, "Invalid control data"
    
    await ClockCycles(dut.clk, 10)

    # Read from an invalid address
    data = await axi_master.read(0x100, 4)
    resp = data.resp
    print(f"resp: {hex(resp)}")
    assert resp == 0x2, "Reading from invalid address did not produce correct error code"

    await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 200)
    #await Timer(1, 'us')



@cocotb.test()
async def test_dma(dut):
    #seed = int(time.time())
    seed = 1753463009
    random.seed(seed)
    print(f"using seed: {seed}")

    #axi_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi"), dut.clk, dut.reset)
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.reset, size=2**32)

    axi_ram.mem[0x000:0x600] = random.randbytes(1536)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    # reset
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    #dut.transfer_start.value = 1

    await ClockCycles(dut.clk, 500)

    for i in range(0x600):
        if axi_ram.mem[i] != axi_ram.mem[0x1000+i]:
            print(f"byte mismatch at index {hex(i)}")
            print(f"{hex(i)} : {hex(axi_ram.mem[i])}")
            print(f"{hex(i+0x1000)} : {hex(axi_ram.mem[i+0x1000])}")
            #quit()

    #assert axi_ram.mem[0x000:0x600] == axi_ram.mem[0x1000:0x1600], "Mem transfer failed"

