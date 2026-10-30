"""Independent GCW v4 reader and integer terrain-v2 test oracle (not runtime code)."""
import struct
import zlib

MAX_BYTES = 48 + 324 * 4096


def validate_tall(path, legacy=None):
    if path.stat().st_size > MAX_BYTES:
        raise ValueError("Oversized tall world")
    data = path.read_bytes()
    if len(data) < 48 or data[:9] != b"GOOSEWLD\x04" or data[9] > 4 or data[10:12] != b"\x04\x00":
        raise ValueError("Invalid tall header")
    sections, low, high, generator, seed = struct.unpack_from("<IiiII", data, 16)
    columns = (2 * data[9] + 1) ** 2
    if sections != 4 * columns or (low, high) != (-16, 48) or any(data[36:48]):
        raise ValueError("Invalid section layout")
    if generator not in (0, 2) or (generator == 0 and seed != 0):
        raise ValueError("Invalid generator metadata")
    if len(data) != 48 + sections * 4096 or any(x > 2 for x in data[48:]):
        raise ValueError("Invalid payload")
    if struct.unpack_from("<I", data, 12)[0] != zlib.adler32(data[:12] + data[16:]):
        raise ValueError("Bad checksum")
    if legacy is not None:
        old = legacy.read_bytes()
        assert old[:8] == b"GOOSEWLD" and old[8] in (1, 2) and old[9] == data[9]
        assert len(old) == 16 + columns * 4096
        assert zlib.adler32(old[:12] + old[16:]) == struct.unpack_from("<I", old, 12)[0]
        layer = columns * 4096
        assert data[48 + layer:48 + 2 * layer] == old[16:]
        assert not any(data[48:48 + layer] + data[48 + 2 * layer:])
        assert generator == seed == 0
    return {"format": 4, "columns": columns, "sections": sections, "min_y": low,
            "max_y_exclusive": high, "generator": generator, "seed": seed,
            "solid_blocks": sum(x != 0 for x in data[48:]), "bytes": len(data)}


def terrain_bytes(seed, radius):
    mask = 0xffffffff

    def lattice(seed, x, z):
        h = seed ^ ((x * 0x9e3779b9) & mask) ^ ((z * 0x85ebca6b) & mask)
        h ^= h >> 16; h = h * 0x7feb352d & mask
        h ^= h >> 15; h = h * 0x846ca68b & mask
        h ^= h >> 16
        return h & 255

    def noise(seed, x, z, scale):
        cx, cz = x // scale, z // scale
        tx, tz = x % scale * 256 // scale, z % scale * 256 // scale
        tx, tz = tx * tx * (768 - 2 * tx) // 65536, tz * tz * (768 - 2 * tz) // 65536
        blend = lambda a, b, t: (a * (256 - t) + b * t) // 256
        a = blend(lattice(seed, cx, cz), lattice(seed, cx + 1, cz), tx)
        b = blend(lattice(seed, cx, cz + 1), lattice(seed, cx + 1, cz + 1), tx)
        return blend(a, b, tz)

    def height(x, z):
        old = 3 + (noise(seed, x, z, 16) * 7 + noise(seed ^ 0xa511e9b3, x, z, 8) * 2) // 256
        return 12 + 2 * old + noise(seed ^ 0x68bc21eb, x, z, 32) * 8 // 256

    heights = {(x, z): height(x, z) for z in range(-radius * 16, (radius + 1) * 16)
               for x in range(-radius * 16, (radius + 1) * 16)}
    out = bytearray(b"GOOSEWLD" + bytes((4, radius, 4, 0)) + bytes(36))
    struct.pack_into("<IiiII", out, 16, 4 * (2 * radius + 1) ** 2, -16, 48, 2, seed)
    for cy in range(-1, 3):
        for cz in range(-radius, radius + 1):
            for cx in range(-radius, radius + 1):
                for y in range(cy * 16, (cy + 1) * 16):
                    for z in range(cz * 16, (cz + 1) * 16):
                        out.extend(1 if y == heights[x, z] - 1 else 2 if y < heights[x, z] else 0
                                   for x in range(cx * 16, (cx + 1) * 16))
    struct.pack_into("<I", out, 12, zlib.adler32(out[:12] + out[16:]))
    return bytes(out)
