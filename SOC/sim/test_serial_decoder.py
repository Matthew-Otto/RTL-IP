import os
import sys
import random
utils_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../python_utils'))
sys.path.insert(0, utils_dir)
from packet_gen import generate_packet

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink

random.seed(2)

ACK = 0x06
NAK = 0x15
XON = 0x11
XOFF = 0x13

async def read_tx(uart_sink, packet_cnt):
    tx_data = []
    uart_sink.clear()
    while len(tx_data) < packet_cnt:
        tx_data.append(int((await uart_sink.read())[0]))
    return tx_data


# send a packet over uart, receive a valid response 
# and then read teh packet out of msg fifo
@cocotb.test()
async def serdec_test1(dut):
    uart_source = UartSource(dut.urx, baud=115200, bits=8)
    uart_sink = UartSink(dut.utx, baud=115200, bits=8)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    dut.ready_pkt.value = 0

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    uart_read = cocotb.start_soon(read_tx(uart_sink, 1))

    data = generate_packet("write", [0x9], [0xde, 0xad, 0xbe, 0xef])

    print(f"full packet: {data}")

    await uart_source.write(data)
    await uart_source.wait()

    await uart_read
    resp = uart_read.result()

    dut._log.info(f"resp is {resp}")
    assert resp == [ACK], "did not receive ack"

    # check packet in fifo
    dut.ready_pkt.value = 1
    cmd = dut.cmd.value
    address = dut.address.value
    rxdata = []
    rxdata.append(dut.data.value)

    dut._log.info("cmd is %x", cmd)
    dut._log.info("addr is %x", address)
    dut._log.info("data is %x", dut.data.value)

    await FallingEdge(dut.clk)
    while True:
        rxdata.append(dut.data.value)
        dut._log.info("data is %x", dut.data.value)
        if dut.end_of_pkt.value:
            break
        await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)

    assert cmd == 1, "receiver got invalid cmd"
    assert address == 0x9, "receiver got invalid addr"
    assert rxdata == [0xde, 0xad, 0xbe, 0xef], "receiver got invalid data"



# test packet flow control
# send a 256 byte packet to fill the buffer and then send another packet
# should receive an XOFF for every byte sent while fifo is full
@cocotb.test()
async def serdec_test2(dut):
    uart_source = UartSource(dut.urx, baud=115200, bits=8)
    uart_sink = UartSink(dut.utx, baud=115200, bits=8)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    dut.ready_pkt.value = 0

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    # Fill buffer with max size packet
    payload = random.randbytes(255)
    pkt = generate_packet("write", [0xde, 0xad, 0xbe, 0xef], payload)

    await uart_source.write(pkt)
    await uart_source.wait()
    rx_byte = int((await uart_sink.read())[0])

    assert rx_byte == ACK, "First packet was not ACKed"

    # send another packet
    pkt = generate_packet("write", [0x5], [0x19])
    await uart_source.write(pkt)
    await uart_source.wait()
    rx_byte = int((await uart_sink.read())[0])

    assert rx_byte == XOFF, "Didn't receive flow control byte."

    

# test concurrent packet transmission
@cocotb.test()
async def serdec_test3(dut):
    uart_source = UartSource(dut.urx, baud=115200, bits=8)
    uart_sink = UartSink(dut.utx, baud=115200, bits=8)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    dut.ready_pkt.value = 0

    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    payload = random.randbytes(255)
    pkt1 = generate_packet("write", [0x0, 0x0], payload)
    pkt2 = generate_packet("write", [0x1, 0x0], payload)
    pkt3 = generate_packet("write", [0x2, 0x0], payload)

    await uart_source.write(pkt1)
    await uart_source.write(pkt2)
    await uart_source.write(pkt3)

    await FallingEdge(dut.clk)

    dut.ready_pkt.value = 1
    for i in range(3):
        while not dut.valid_pkt.value:
            await FallingEdge(dut.clk)

        cmd = dut.cmd.value
        address = dut.address.value
        rxdata = []
        rxdata.append(dut.data.value)

        await FallingEdge(dut.clk)
        while True:
            while not dut.valid_pkt.value:
                await FallingEdge(dut.clk)

            rxdata.append(dut.data.value)

            if dut.end_of_pkt.value:
                break
            await FallingEdge(dut.clk)
        await FallingEdge(dut.clk)

        #srxdata = [hex(int(x)) for x in rxdata]
        #print(srxdata)

        assert cmd == 0x1, "Received incorrect cmd"
        assert address == i<<8, "Received incorrect address"
        assert bytes(rxdata) == payload, "Received incorrect payload"

    #await uart_source.wait()
    #rx_byte = int((await uart_sink.read())[0])