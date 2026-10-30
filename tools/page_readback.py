"""Independent byte-level validation of GooseCraft's directory format 3."""
from pathlib import Path
import struct
import zlib


def validate_pages(root, expected_gcw=None):
    root = Path(root)
    path = root / "index.gci"
    if path.stat().st_size != 1024:
        raise ValueError("Index length")
    data = path.read_bytes()
    crc = lambda b: zlib.adler32(b[:12] + b[16:])
    if (data[:8], data[8], data[11], data[28:32], data[1004:]) != (b"GOOSEIDX", 3, 0, bytes(4), bytes(20)):
        raise ValueError("Index tags/reserved fields")
    radius, generator = data[9:11]
    seed, serial, count = struct.unpack_from("<III", data, 16)
    slots = (2 * max(1, radius) + 1) ** 2
    if radius > 4 or generator > 1 or serial > 2147483647 or (generator == 0 and seed != 0) or count != (1 if radius == 0 else slots):
        raise ValueError("Index metadata")
    if struct.unpack_from("<I", data, 12)[0] != crc(data):
        raise ValueError("Index checksum")
    expected = None
    if expected_gcw is not None:
        raw = Path(expected_gcw).read_bytes()
        if raw[:8] != b"GOOSEWLD" or raw[9] != radius or len(raw) != 16 + count * 4096:
            raise ValueError("Expected GCW shape")
        if struct.unpack_from("<I", raw, 12)[0] != crc(raw):
            raise ValueError("Expected GCW checksum")
        expected = [raw[i:i + 4096] for i in range(16, len(raw), 4096)]
    cursor = 0
    references = 0
    total = 0
    width = 2 * max(1, radius) + 1
    for at in range(81):
        generation, checksum, solids = struct.unpack_from("<III", data, 32 + at * 12)
        active = at < slots and (radius != 0 or at == 4)
        if not active:
            if (generation, checksum, solids) != (0, 0, 0):
                raise ValueError("Inactive index entry")
            continue
        if generation > serial or solids > 4096 or (generation == 0 and (generator == 0 or checksum != 0)):
            raise ValueError("Page index entry")
        total += solids
        if expected is not None and sum(x != 0 for x in expected[cursor]) != solids:
            raise ValueError("Index block count differs from GCW")
        if generation:
            x, z = at % width - max(1, radius), at // width - max(1, radius)
            page = root / f"chunk_{x}_{z}_{generation}.gcp"
            if page.stat().st_size != 4128:
                raise ValueError("Page length")
            payload = page.read_bytes()
            if payload[:12] != b"GOOSEPG3\x03\0\0\0" or struct.unpack_from("<iiII", payload, 16) != (x, z, generation, solids):
                raise ValueError("Page identity")
            if struct.unpack_from("<I", payload, 12)[0] != checksum or crc(payload) != checksum:
                raise ValueError("Page checksum/index binding")
            if max(payload[32:]) > 2 or sum(v != 0 for v in payload[32:]) != solids:
                raise ValueError("Page blocks")
            if expected is not None and payload[32:] != expected[cursor]:
                raise ValueError("Page differs from GCW blocks")
            references += 1
        cursor += 1
    return {"format": 3, "radius": radius, "generator": generator, "seed": seed,
            "serial": serial, "chunks": count, "solid_blocks": total,
            "referenced_pages": references, "index_bytes": 1024, "referenced_page_bytes": references * 4128,
            "expected_gcw_checked": expected is not None}
