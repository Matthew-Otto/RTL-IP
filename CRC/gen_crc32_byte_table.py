

POLY = 0xEDB88320

crc_table = [0] * 256
crc32 = 1
i = 128
while i:
    crc32 = (crc32 >> 1) ^ (POLY if crc32 & 0x1 else 0)
    for j in range(0, 256, 2*i):
        crc_table[i+j] = crc32 ^ crc_table[j]
    i >>= 1


for i,c in enumerate(crc_table):
    print(f"crc_rom[{i}] = 32'h{format(c, '08x')};")