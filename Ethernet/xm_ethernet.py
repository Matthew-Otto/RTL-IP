#!/usr/bin/env python3

from socket import socket, htons, AF_PACKET, SOCK_RAW, ETH_P_ALL
import struct
import random
from time import sleep

INTERFACE = "enp14s0"
ETH_TYPE = 0x88B5

dest_mac = b'\xff\xff\xff\xff\xff\xff'
src_mac = b'\x00\x07\xed\x12\x34\x56'

def main():
    i = 0
    while True:
        payload = random.randbytes(1500)
        i += 1
        frame = gen_frame(dest_mac, src_mac, ETH_TYPE.to_bytes(2, "big"), payload)

        print(f"frame len: {len(frame)}")

        #write_romfile('test.txt', frame)
        #write_pcap('test.pcap', frame)
        
        print([hex(b) for b in frame])

        
        sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_TYPE))
        sock.bind((INTERFACE, ETH_TYPE))
        sock.settimeout(1.0)

        send_frame(sock, frame, 1)
        print(f"cnt: {i}")
        rx_frame = receive_frame(sock)
        if rx_frame:
            process_frame(rx_frame)

        if frame != rx_frame:
            print("\n\nrx frame did not match tx frame\n\n")
            quit()

        input("press a key to repeat")


def send_frame(sock: socket, frame: bytes, cnt: int):
    for _ in range(cnt):
        sock.send(frame)

def receive_frame(sock: socket):
    try:
        raw_frame = sock.recv(65535)
        return raw_frame
    except:
        pass


def gen_frame(dest: bytes, src: bytes, type: bytes, payload: bytes) -> bytes:
    payload = payload.ljust(46, b'\x00')
    frame = dest + src + type + payload
    #fcs = compute_crc32(frame)
    #frame += fcs
    return frame


def process_frame(frame: bytes):
    eth_header = frame[:14]
    dest_mac, src_mac, eth_type = struct.unpack("!6s6sH", eth_header)
    payload = frame[14:-4]
    fcs = frame[-4:]

    dest_mac = ':'.join(format(x, '02x') for x in dest_mac)
    src_mac = ':'.join(format(x, '02x') for x in src_mac)

    print(f"Destination MAC: {dest_mac}")
    print(f"Source MAC: {src_mac}")
    print(f"EtherType: {hex(eth_type)}")
    print(f"Payload: {payload}")
    print([hex(b) for b in frame])


def compute_crc32(frame_bytes: bytes) -> bytes:
    """
    Compute Ethernet CRC-32 (IEEE 802.3) for a given frame.
    frame_bytes: raw bytes from Destination MAC to end of payload (no preamble/SFD/FCS)
    Returns 32-bit CRC as bytes
    """
    crc = 0xFFFFFFFF
    poly = 0xEDB88320  # reflected 0x04C11DB7

    for byte in frame_bytes:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ poly
            else:
                crc >>= 1

    inv_crc = (~crc) & 0xFFFFFFFF
    return struct.pack("<I", inv_crc)


# Save to a .pcap file for Wireshark
def write_pcap(filename: str, frame: bytes):
    # PCAP global header
    pcap_global_hdr = struct.pack(
        "<IHHIIII",
        0xa1b2c3d4, # magic
        2, 4,       # version major, minor
        0, 0,       # thiszone, sigfigs
        65535,      # snaplen
        1           # LINKTYPE_ETHERNET
    )
    # Per-packet header
    ts_sec = 0
    ts_usec = 0
    incl_len = orig_len = len(frame)
    pcap_pkt_hdr = struct.pack("<IIII", ts_sec, ts_usec, incl_len, orig_len)

    with open(filename, "wb") as f:
        f.write(pcap_global_hdr)
        f.write(pcap_pkt_hdr)
        f.write(frame)


def write_romfile(filename: str, frame: bytes):
    data = ""
    for idx,b in enumerate(frame):
        data += f"packet[{idx}] = 8'h{format(b, '02X')};\n"
    
    with open(filename, "w") as f:
        f.write(data)


if __name__ == "__main__":
    main()
