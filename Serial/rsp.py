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


class RSP:
    def __init__(self, rtd = 0.5, src_mac=0x123456ABCDEF, dest_mac=0x0007ED123456, dump_sim=False):
        self.seq_num = 0
        self.unacked_packets = {}
        self.rtd = rtd
        self.src_mac = src_mac.to_bytes(6)
        self.dest_mac = dest_mac.to_bytes(6)
        self.dump_sim = dump_sim
        self.rx_buffer ={}
        # async loop
        self.loop = asyncio.get_event_loop()
        self.rx_event = asyncio.Event()
        if not self.dump_sim:
            # socket
            self.sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_TYPE))
            self.sock.bind((INTERFACE, ETH_TYPE))
            self.sock.setblocking(False)
            # register read handler
            self.loop.add_reader(self.sock.fileno(), self._receive)
        
        #self.loop.create_task(self.debug_trigger())

    async def debug_trigger(self):
        await asyncio.sleep(10)
        print("bbb")
        self.rx_event.set()

    def write_data(self, address: int, data: bytes):
        """Send packets to fpga, wait until they have all been acknowledged"""
        self.loop.run_until_complete(self._write_data_async(address, data))


    def read_data(self, address: int, byte_cnt: int) -> bytes:
        """Send read requests to fgpa, wait for data"""
        data = self.loop.run_until_complete(self._read_data_async(address, byte_cnt))
        return data


    async def _write_data_async(self, address: int, data: bytes):
        max_payload_len = MAX_FRAME_SIZE - 29
        for payload in self.batch(data, max_payload_len):
            frame = self._gen_frame(self._gen_write_packet(address, payload))
            await self._send_frame(frame)
            address += len(payload)
            #await asyncio.sleep(0.001)

        while self.unacked_packets:
            await self.rx_event.wait()
            self.rx_event.clear()
        

    async def _read_data_async(self, address: int, byte_cnt: int) -> bytes:
        max_payload_len = MAX_FRAME_SIZE - 29
        req_seqs = []
        while byte_cnt:
            req_len = min(byte_cnt, max_payload_len)
            frame = self._gen_frame(self._gen_read_packet(address, req_len))
            seq_num = await self._send_frame(frame)
            req_seqs.append(seq_num)
            byte_cnt -= req_len
            address += req_len

            while len(self.unacked_packets) > 2:
                await asyncio.sleep(0.01)

        # wait for all read responses (abusing sets bc im lazy)
        missing_seq = set(req_seqs)
        missing_seq -= self.rx_buffer.keys()
        while missing_seq:
            await self.rx_event.wait()
            self.rx_event.clear()
            missing_seq -= self.rx_buffer.keys()

        # collect requested data
        data = b''
        for seq_num in req_seqs:
            data += self.rx_buffer.pop(seq_num)
        return data


    async def _send_frame(self, frame):
        print(f"Transmitting packet {self.seq_num}")
        if self.dump_sim:
            frame += self.compute_crc32(frame)
            ff = ", ".join([f"{i:#04x}" for i in list(frame)])
            with open("stim.dump", "w") as stim:
                stim.write(f"[{ff}]\n")
        else:
            await self.loop.sock_sendall(self.sock, frame)
            # Put packet in retransmit queue
            task = self.loop.create_task(self._retransmit_packet(self.seq_num, frame))
            self.unacked_packets[self.seq_num] = task
        
        # increment seq_num
        prev_seq_num = self.seq_num
        self.seq_num += 1
        if self.seq_num > 2 ** 16:
            self.seq_num = 0
        return prev_seq_num


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
            if seq_num in self.unacked_packets:
                task = self.unacked_packets.pop(seq_num)
                task.cancel()
                print(f"ACK received for {seq_num}")

        elif opcode == OPCODE["READ_RSP"]:
            if seq_num in self.unacked_packets:
                task = self.unacked_packets.pop(seq_num)
                task.cancel()
                print(f"Resp received for {seq_num}")
            
            address, len = struct.unpack_from("!IH", packet, 3)
            payload = packet[9:]
            self.rx_buffer[seq_num] = payload
        self.rx_event.set()


    async def _retransmit_packet(self, seq_num, packet):
        """Sends a packet every self.rtd seconds until it is ACKed"""
        try:
            while True:
                await asyncio.sleep(self.rtd)
                if seq_num in self.unacked_packets:
                    print(f"Retransmitting packet {seq_num}")
                    self.sock.send(packet)
                else:
                    break
        except asyncio.CancelledError:
            pass


    def _gen_write_packet(self, address: int, data: bytes) -> bytes:
        """Wrap data and address in a write packet"""
        packet =  OPCODE["WRITE"].to_bytes(1) # opcode (write)
        packet += self.seq_num.to_bytes(2)    # seqnum (2 byte)
        packet += address.to_bytes(4)         # address (4 byte)
        packet += len(data).to_bytes(2)       # len (2 bytes)
        packet += data                        # payload (len bytes)
        return packet
    

    def _gen_wrick_ack_packet(self) -> bytes:
        packet =  OPCODE["WRITE_ACK"].to_bytes(1) # opcode (write)
        packet += self.seq_num.to_bytes(2)        # seqnum (2 byte)
        return packet


    def _gen_read_packet(self, address: int, byte_cnt: int) -> bytes:
        """Wrap address and data_len in a read packet"""
        packet = OPCODE["READ"].to_bytes(1)  # opcode (read)
        packet += self.seq_num.to_bytes(2)   # seqnum (2 byte)
        packet += address.to_bytes(4)        # address (4 byte)
        packet += byte_cnt.to_bytes(2)       # len (2 bytes)
        return packet

    def _gen_frame(self, packet: bytes) -> bytes:
        """Wrap packet in an ethernet frame"""
        frame =  self.dest_mac
        frame += self.src_mac
        frame += ETH_TYPE.to_bytes(2)
        frame += packet.ljust(46, b"\x00")
        return frame
    
    
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


    def batch(self, data: bytes, n: int) -> bytes:
        for i in range(0, len(data), n):
            yield data[i:i+n]