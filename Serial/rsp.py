# reliable serial protocol

## fixed header
# opcode (1 byte)
# seq_num (2 byte)

# opcode specific header

## write:
# opcode (write)
# seqnum (2 byte)
# address (4 byte)
# len (2 bytes)
# payload (len bytes)

## write ack:
# opcode (ack)
# seqnum (2 byte)

## read:
# opcode (read)
# seqnum (2 byte)
# address (4 byte)
# len (2 bytes)

## read response
# opcode (read rsp)
# seqnum (2 byte)
# address (4 byte)
# len (2 bytes)
# payload (len bytes)



import asyncio
import struct
from socket import socket, htons, AF_PACKET, SOCK_RAW

INTERFACE = "enp14s0"
ETH_TYPE = 0x88B5

OPCODE = {
    "WRITE": 0x10,
    "WRITE_ACK": 0x11,
    "READ": 0x20,
    "READ_RSP": 0x21,
}

MAX_FRAME_SIZE = 1498

# todo move this to class
condition = asyncio.Condition()

class RSP:
    def __init__(self, rtd = 1.0, src_mac=0x123456ABCDEF, dest_mac=0x0007ED123456, print_packet=False):
        self.seq_num = 0
        self.tx_window = {}
        self.rtd = rtd
        self.src_mac = src_mac.to_bytes(6)
        self.dest_mac = dest_mac.to_bytes(6)
        self.print_packet = print_packet
        self.rx_buffer ={}
        self.rx_event = asyncio.Event()
        if not self.print_packet:
            # socket
            self.sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_TYPE))
            self.sock.bind((INTERFACE, ETH_TYPE))
            self.sock.setblocking(False)
            # async loop
            self.loop = asyncio.get_event_loop()
            # register read handler
            self.loop.add_reader(self.sock.fileno(), self._receive)


    def write_data(self, address: int, data: bytes):
        """Send address and data to write, wait for ack from fpga"""
        packet = OPCODE["WRITE"].to_bytes(1)  # opcode (write)
        packet += self.seq_num.to_bytes(2)    # seqnum (2 byte)
        packet += address.to_bytes(4)         # address (4 byte)
        packet += len(data).to_bytes(2)       # len (2 bytes)
        packet += data                        # payload (len bytes)
        self._send_packet(packet)


    def read_data(self, address: int, byte_cnt: int):
        """Send address to read from, wait for data from fpga"""
        if byte_cnt > MAX_FRAME_SIZE:
            raise Exception("Requested byte count is too large to fit in an ethernet frame")
        
        packet = OPCODE["READ"].to_bytes(1)  # opcode (read)
        packet += self.seq_num.to_bytes(2)   # seqnum (2 byte)
        packet += address.to_bytes(4)        # address (4 byte)
        packet += byte_cnt.to_bytes(2)  # len (2 bytes)
        seq_num = self._send_packet(packet)

        return self.loop.run_until_complete(self._retrieve(seq_num))


    def _send_packet(self, packet):
        """Wrap packet in an ethernet frame and send it"""
        frame = self.dest_mac
        frame += self.src_mac
        frame += ETH_TYPE.to_bytes(2)
        frame += packet.ljust(46, b"\x00")

        print(f"Transmitting packet {self.seq_num}")
        if self.print_packet:
            frame += self.compute_crc32(frame)
            print(", ".join([f"{i:#04x}" for i in list(frame)]))
        else:
            self.sock.send(frame)
            # Put packet in retransmit queue
            task = self.loop.create_task(self._retransmit(self.seq_num, packet))
            self.tx_window[self.seq_num] = task
        
        # increment seq_num
        prev_seq_num = self.seq_num
        self.seq_num += 1
        if self.seq_num > 2 ** 16:
            self.seq_num = 0
        return prev_seq_num


    async def _retrieve(self, seq_num: int) -> bytes:
        """returns read response with specified seq_num when it arrives"""
        if seq_num not in self.rx_buffer:
            await self.rx_event.wait()
        return self.rx_buffer.pop(seq_num)


    def _receive(self):
        """Receives a packet and decodes it"""
        try:
            frame = self.sock.recv(65535)
        except BlockingIOError:
            pass

        # strip ethernet header
        dest, src, ethtype = struct.unpack_from("!6s6sH", frame, 0)
        packet = frame[14:]

        opcode, seq_num = struct.unpack_from("!BH", packet)

        if opcode == OPCODE["WRITE_ACK"]:
            if seq_num in self.tx_window:
                task = self.tx_window.pop(seq_num)
                task.cancel()
                print(f"ACK received for {seq_num}")

        elif opcode == OPCODE["READ_RSP"]:
            if seq_num in self.tx_window:
                task = self.tx_window.pop(seq_num)
                task.cancel()
                print(f"Resp received for {seq_num}")
            
            address, len = struct.unpack_from("!IH", packet, 3)
            payload = packet[9:]
            self.rx_buffer[seq_num] = payload
            self.rx_event.set()


    async def _retransmit(self, seq_num, packet):
        """Sends a packet every self.rtd seconds until it is ACKed"""
        try:
            while True:
                await asyncio.sleep(self.rtd)
                if seq_num in self.pending:
                    print(f"Retransmitting packet {seq_num}")
                    self.sock.send(packet)
                else:
                    break
        except asyncio.CancelledError:
            pass

    
    def compute_crc32(self, frame_bytes: bytes) -> bytes:
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
    

    def write_pcap(self, filename: str, frame: bytes):
        """ Saves frame to a .pcap file for analysis in Wireshark"""
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
