import socket
import struct

INTERFACE = "enp14s0"

dest_mac = b'\xff\xff\xff\xff\xff\xff'
src_mac = b'\x00\x07\xed\x2e\x05\x13'
ethertype = b'\x08\x00'


def main():
    payload = b"Hello!"
    frame = gen_frame(dest_mac, src_mac, ethertype, payload)

    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW)
    s.bind((INTERFACE, 0))

    for _ in range(10000000):
        s.send(frame)



def gen_frame(dest: bytes, src: bytes, type: bytes, payload: bytes) -> bytes:
    payload = payload.ljust(46, b'\x00')
    frame = dest + src + type + payload
    fcs = compute_crc32(frame)
    frame += fcs
    return frame


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

if __name__ == "__main__":
    main()
