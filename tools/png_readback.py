"""Read the non-interlaced RGBA8 PNGs produced by the native renderer.

This is a test reader, using only Python's standard library, not an image
editor. Reconstruct PNG scanlines so GPU comparisons don't depend on Pillow.
"""
import struct
import zlib


def rgba(path):
    blob = path.read_bytes()
    if blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not a PNG")
    width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", blob[16:29])
    if (width, height, depth, color, compression, filtering, interlace) != (640, 480, 8, 6, 0, 0, 0):
        raise ValueError("Expected a 640x480 non-interlaced RGBA8 renderer PNG")
    compressed = bytearray()
    offset = 8
    while offset < len(blob):
        length = struct.unpack(">I", blob[offset:offset + 4])[0]
        kind = blob[offset + 4:offset + 8]
        if kind == b"IDAT": compressed.extend(blob[offset + 8:offset + 8 + length])
        offset += length + 12
        if kind == b"IEND": break
    raw = zlib.decompress(compressed)
    stride = width * 4
    if len(raw) != height * (stride + 1):
        raise ValueError("Unexpected PNG scanline size")
    pixels = bytearray()
    previous = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        method = raw[start]
        row = bytearray(raw[start + 1:start + stride + 1])
        if method not in range(5): raise ValueError("Invalid PNG filter")
        if method:
            for i, value in enumerate(row):
                left = row[i - 4] if i >= 4 else 0
                up = previous[i]
                corner = previous[i - 4] if i >= 4 else 0
                if method == 1: predictor = left
                elif method == 2: predictor = up
                elif method == 3: predictor = (left + up) // 2
                else:
                    estimate = left + up - corner
                    dl, du, dc = abs(estimate - left), abs(estimate - up), abs(estimate - corner)
                    predictor = left if dl <= du and dl <= dc else up if du <= dc else corner
                row[i] = (value + predictor) & 255
        pixels.extend(row)
        previous = row
    return bytes(pixels)


def differences(optimized, reference):
    """Record raw GPU differences; this makes no image-equivalence assertion."""
    a, b = rgba(optimized), rgba(reference)
    return [{"x": (i // 4) % 640, "y": (i // 4) // 640,
             "optimized": list(a[i:i + 4]), "reference": list(b[i:i + 4])}
            for i in range(0, len(a), 4) if a[i:i + 4] != b[i:i + 4]]


def compare_boundary_pixels(optimized, reference):
    a, b = rgba(optimized), rgba(reference)
    changed = [i for i in range(0, len(a), 4) if a[i:i + 4] != b[i:i + 4]]
    if len(changed) > 4:
        raise RuntimeError(f"Reference image differs at {len(changed)} pixels, limit 4")
    clear = bytes((15, 23, 35, 255))
    result = []
    for i in changed:
        x, y = (i // 4) % 640, (i // 4) // 640
        if not 52 <= y < 416:
            raise RuntimeError("HUD pixels must match exactly")
        if a[i:i + 4] != clear and b[i:i + 4] != clear:
            raise RuntimeError("Only geometry/clear boundary coverage may differ")
        solid_color = a[i:i + 4] if a[i:i + 4] != clear else b[i:i + 4]
        # Both images must actually have this geometry color and background
        # in the local neighborhood: tolerate an edge, never a missing face.
        for image in (a, b):
            neighbors = {image[(ny * 640 + nx) * 4:(ny * 640 + nx) * 4 + 4]
                         for ny in range(max(0, y - 1), min(480, y + 2))
                         for nx in range(max(0, x - 1), min(640, x + 2))}
            if clear not in neighbors or solid_color not in neighbors:
                raise RuntimeError("Changed pixel is not a shared geometry boundary")
        result.append({"x": x, "y": y, "optimized": list(a[i:i + 4]), "reference": list(b[i:i + 4])})
    return {"changed_pixels": len(changed), "limit": 4, "pixels": result}
