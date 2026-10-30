"""Independent byte and GPU readback oracle; never used by the game."""
import hashlib
import json
from pathlib import Path
from png_readback import rgba


def pixel(layer, x, y):
    grain = (17*x + 29*y + 7*x*y + 11*layer) % 31
    fleck = (13*x + 19*y) % 23 == 0
    if layer == 0 or layer == 1 and y < 3 + 7*x % 3:
        return bytes((47+grain//2, 126+grain, 61+grain//3, 255))
    if layer == 3:
        vein = (y+x//4) % 7 == 0
        return bytes(((145 if vein else 183)+grain,
                      (96 if vein else 132)+grain//2, 82 if fleck else 55+grain//3, 255))
    return bytes((93 if fleck else 111+grain, 74+grain//2, 43+grain//3, 255))


def tiles():
    return b"".join(pixel(layer, x, y) for layer in range(4) for y in range(16) for x in range(16))


def validate_tiles(blob):
    fixture = json.loads((Path(__file__).resolve().parents[1] / "tests/fixtures/texture-vectors.json").read_text())
    expected = tiles()
    if blob != expected or len(blob) != 4096 or hashlib.sha256(blob).hexdigest() != fixture["sha256"]:
        raise ValueError("Goose tile bytes differ from independent oracle/golden")
    for layer in range(4):
        if hashlib.sha256(blob[layer*1024:(layer+1)*1024]).hexdigest() != fixture["layers"][layer]["sha256"]:
            raise ValueError("Tile layer differs from golden")


def validate_probe(folder):
    # Identity clip-space test: a 2x2-block quad covers the framebuffer.
    # At 640x480 each of the 16 texels spans 20x15 pixels per repeat.
    # Pixel centers are strictly inside texels, away from rounding boundaries.
    results = {}
    for layer in range(4):
        expected = b"".join((b"".join(pixel(layer, x, y) * 20 for x in range(16)) * 2) * 15
                            for y in range(16)) * 2
        for axis in range(3):
            path = folder / f"tiles-{axis}-{layer}.png"
            actual = rgba(path)
            if actual != expected:
                mismatches = sum(actual[i:i+4] != expected[i:i+4] for i in range(0, len(expected), 4))
                raise ValueError(f"GPU tile layer/repeat/projection mismatch: {path.name}: {mismatches} pixels")
            results[path.name] = {"checked_pixels":640*480, "mismatches":0,
                                  "png_sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
    return {"frames":12, "checked_pixels":12*640*480, "mismatches":0,
            "axes":3, "layers":4, "negative_coordinates":True,
            "world_span_per_axis":2, "texels_per_block":16, "images":results,
            "scope":"Shared production texture pipeline, nearest repeat, white vertex light, software Vulkan"}
