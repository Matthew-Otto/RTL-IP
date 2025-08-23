#!/bin/python3

import random

from rsp import RSP

def main():
    random.seed(123)
    conn = RSP(dump_sim=False)
    data = random.randbytes(2**16)
    conn.write_data(0x0, data)
    #print(", ".join([f"{i:#04x}" for i in list(data[2000:2100])]))

    for i in range(0, len(data), 1000):
        payload = conn.read_data(i, 1000)
        if payload != data[i:i+1000]:
            print(payload in data)
            print(data.find(payload))

            #print(f"i: {i}")
            #print(list(payload))
            #print(list(data[i:i+1000]))
            #print(f"Error at idx {idx} - sent byte {g} =/= read byte {r}")
            break
    #print(", ".join([f"{i:#04x}" for i in list(payload)]))

    #print(payload in data)
    #print(data.find(payload))

    #for idx,(g,r) in enumerate(zip(data,payload)):
    #    if g != r:
    #        print(f"Error at idx {idx} - sent byte {g} =/= read byte {r}")



if __name__ == "__main__":
    main()