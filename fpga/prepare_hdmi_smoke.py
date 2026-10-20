"""Prepare DDR test bars and PS initialization for start_hdmi_smoke_jtag.tcl."""

from pathlib import Path
from zipfile import ZipFile


root = Path(__file__).resolve().parent.parent
xsa = root / "artifacts" / "zybo_camera_system.xsa"
out = root / "build" / "jtag"
out.mkdir(parents=True, exist_ok=True)

with ZipFile(xsa) as archive:
    (out / "ps7_init.tcl").write_bytes(archive.read("ps7_init.tcl"))

width, height = 640, 480
row = bytes((min((x // 80) * 32, 255) for x in range(width)))
frame = row * height
assert len(frame) == width * height
(out / "hdmi_bars_640x480.bin").write_bytes(frame)
print(f"Prepared {out / 'ps7_init.tcl'} and {len(frame)}-byte frame")
