from crc16_gen import serial_order_crc16

cmd_map = {
    "WRITE_WORD"   : 0x00,
    "READ_WORD"   : 0x01,
}


def generate_packet(cmd: str, address: bytes, data: bytes = []) -> bytes:
    if cmd not in cmd_map:
        raise Exception("invalid cmd")
    else:
        cmd = cmd_map[cmd]

    packet = [0x7e]                            # SOH
    packet += [cmd]                            # cmd
    packet += [0] * (4-len(address)) + address # addr
    packet += [len(data)]                      # payload length
    packet += data                             # payload
    packet += serial_order_crc16(packet)       # CRC16
    return bytes(packet)

