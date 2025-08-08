import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotbext.uart import UartSource, UartSink


@cocotb.test()
async def uart_rx_test(dut):
    dut.reset.value = 0
    dut.ready.value = 1
    uart_source = UartSource(dut.rx, baud=115200, bits=8)

    # start system clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    await uart_source.write([0xde, 0xad, 0xbe, 0xef])
    await uart_source.wait()

    dut._log.info("data is %x", dut.data.value)
    assert dut.data.value == 0xef, "rx_value is not 0xef"

