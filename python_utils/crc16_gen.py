def reverse_bits(byte) -> int:
    return int('{:08b}'.format(byte)[::-1], 2)

def serial_order_crc16(data: bytes, poly: int = 0x11021) -> bytes:
    crc = 0
    for byte in data:
        byte = reverse_bits(byte)
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = (crc << 1) ^ poly
            else:
                crc <<= 1
            crc &= 0xFFFF  # Keep CRC within 16 bits

    crc = bytes([reverse_bits(b) for b in crc.to_bytes(2)])
    return crc
