import serial
from packet_gen import generate_packet

s = serial.Serial('/dev/ttyUSB0', 115200)
s.reset_input_buffer()

def write(addr, data):
    pkt = generate_packet("WRITE_WORD", addr, data)
    print(f"writing write packet: {pkt}")
    s.write(pkt)
    ack = s.read()
    if ack != b'\x06':
        raise Exception("write fail")

def read(addr, n=1):
    pkt = generate_packet("READ_WORD", addr)
    print(f"writing read packet: {pkt}")
    s.write(pkt)
    ack = s.read()
    if ack != b'\x06':
        raise Exception("read fail")
    
    for _ in range(n):
        b = s.read()
        print(f"byte: {hex(b[0])}")
    #data = s.read(n)
    #return data


def main():

    write([0x20], [0xba, 0x11])
    write([0x28], [0xd0, 0x09])
    rdata = read([0x28], 4)
    rdata = read([0x20], 4)

    print(f"data?: {rdata}")


main()