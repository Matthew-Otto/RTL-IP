import cocotb
from cocotb.triggers import Timer, ReadOnly, RisingEdge, FallingEdge, ClockCycles
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink

tx_data = []

async def read_tx(uart_sink, packet_cnt):
    uart_sink.clear()
    while len(tx_data) < packet_cnt:
        tx_data.append(int((await uart_sink.read())[0]))

@cocotb.test()
async def uart_tx_test(dut):
    uart_sink = UartSink(dut.tx, baud=115200, bits=8)

    payload = [0xde, 0xad, 0xbe, 0xef]

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    # start uart read coroutine
    cocotb.start_soon(read_tx(uart_sink, len(payload)))

    # reset
    dut.areset.value = 1
    await ClockCycles(dut.clk, 5, rising=True)
    dut.areset.value = 0
    await ClockCycles(dut.clk, 5, rising=True)

    for b in payload:
        dut.data_in.value = b
        dut.data_write_valid.value = 1

        await ReadOnly()

        while not dut.data_write_ready.value:
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    dut.data_write_valid.value = 0

    while True:
        await ReadOnly()
        if int(dut.state.value) == 0:
            break
        await ClockCycles(dut.clk, 100)
    await ClockCycles(dut.clk, 100)

    dut._log.info(f"payload is {payload}")
    dut._log.info(f"tx_data is {tx_data}")
    assert payload == tx_data, "transmitted data does not match payload"

