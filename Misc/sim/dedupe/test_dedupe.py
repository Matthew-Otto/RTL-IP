import random
import time
from collections import Counter

import cocotb
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock



@cocotb.test()
async def test_read_write(dut):

    seed = 1758497259 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")
    dut._log.setLevel("DEBUG")

    iters = 10

    word_cnt = 16
    word_size = 12

    cocotb.start_soon(Clock(dut.clk, 2, units="ps").start())


    pool = [random.getrandbits(word_size) for _ in range(8)]

    for _ in range(iters):
        longword = 0
        data = [random.choice(pool) for _ in range(word_cnt)]
        for i,word in enumerate(data):
            longword |= word << (i*word_size)

        hist = Counter(data)
        dut.data_in.value = longword

        await RisingEdge(dut.clk)

        print(hist)
        print(dut.data_out_cnt.value)


