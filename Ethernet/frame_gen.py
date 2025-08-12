import struct

def main():
    # Example: minimal Ethernet II frame
    dst_mac = bytes.fromhex("ff ff ff ff ff ff")   # Broadcast
    src_mac = bytes.fromhex("00 11 22 33 44 55")
    eth_type = bytes.fromhex("08 00")              # IPv4
    payload = bytes.fromhex("""45 00
00 54 e8 f1 40 00 40 01 36 fc 0a 00 02 64 0a 00
02 58 08 00 8e 48 00 02 00 01 f9 2e 9a 68 00 00
00 00 0a 4a 0d 00 00 00 00 00 10 11 12 13 14 15
16 17 18 19 1a 1b 1c 1d 1e 1f 20 21 22 23 24 25
26 27 28 29 2a 2b 2c 2d 2e 2f 30 31 32 33 34 35
36 37""")
    # TODO pad to min payload

    frame_wo_fcs = dst_mac + src_mac + eth_type + payload

    # Calculate and append CRC
    fcs = ethernet_crc32(frame_wo_fcs)
    frame_with_fcs = frame_wo_fcs + fcs

    for b in frame_with_fcs:
        print(f"{int(b):02x}")

    write_pcap("test_frame_with_fcs.pcap", frame_with_fcs)

    print(f"FCS: 0x{fcs}")
    print("Saved to test_frame_with_fcs.pcap")



def ethernet_crc32(frame_bytes: bytes) -> bytes:
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