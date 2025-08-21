#!/bin/python3

import random

from rsp import RSP

def main():
    random.seed(123)
    conn = RSP()
    data = random.randbytes(2**10)
    conn.write_data(0xdead, data)
    payload = conn.read_data(0xdead, 2**10)

    print(payload)

if __name__ == "__main__":
    main()