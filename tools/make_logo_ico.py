# Regenerates art/icons/game/logo.ico (multi-size) from logo.png
from pathlib import Path
from PIL import Image
import struct
import io

root = Path(__file__).resolve().parents[1]
src = root / "art/icons/game/logo.png"
out = root / "art/icons/game/logo.ico"

im = Image.open(src).convert("RGBA")
sizes = [16, 32, 48, 64, 128, 256]
png_blobs = []
for s in sizes:
	frame = im.resize((s, s), Image.Resampling.NEAREST)
	buf = io.BytesIO()
	frame.save(buf, format="PNG")
	png_blobs.append((s, buf.getvalue()))

count = len(png_blobs)
header = struct.pack("<HHH", 0, 1, count)
entries = []
offset = 6 + 16 * count
data = b""
for s, blob in png_blobs:
	w = 0 if s >= 256 else s
	h = 0 if s >= 256 else s
	entries.append(struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(blob), offset))
	offset += len(blob)
	data += blob

out.write_bytes(header + b"".join(entries) + data)
print(f"Wrote {out} ({out.stat().st_size} bytes, {count} sizes)")
