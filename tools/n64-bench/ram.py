#!/usr/bin/env python3
"""Extrai a RDRAM (big-endian, 8 MB) de um savestate RZIP do Mupen64Plus-Next."""
import struct, sys, zlib
def rzip(path):
    d = open(path, "rb").read()
    assert d[:8] == b"#RZIPv\x01#"
    total = struct.unpack_from("<Q", d, 12)[0]; pos = 20; out = bytearray()
    while pos < len(d):
        n = struct.unpack_from("<I", d, pos)[0]; pos += 4
        out += zlib.decompress(d[pos:pos+n]); pos += n
    assert len(out) == total, (len(out), total)
    return bytes(out)
def rdram(path):
    raw = rzip(path)
    i = raw.find(b"DLEZ")  # "ZELD" de "ZELDAZ" (SaveContext+0x1C) em palavras host-endian
    while i != -1 and (i < 0x11AC9C or raw[i+6:i+8] != b"ZA"): i = raw.find(b"DLEZ", i + 1)
    base = i - 0x11AC9C
    host = raw[base:base + 0x800000]
    # desfaz a troca de bytes por palavra de 32 bits -> memoria como o N64 ve
    be = bytearray(len(host))
    be[0::4], be[1::4], be[2::4], be[3::4] = host[3::4], host[2::4], host[1::4], host[0::4]
    return raw, base, bytes(be)
if __name__ == "__main__":
    raw, base, m = rdram(sys.argv[1])
    print("estado", len(raw), "RDRAM em", hex(base), "magic:", m[0x11AC9C:0x11ACA2], "vida:", hex(struct.unpack_from(">H", m, 0x11ACB0)[0]))
