# Live Zybo Ethernet detection

This path sends 640x480 Bayer8 frames from the OV5647/VDMA DDR buffers as CRC-protected UDP packets to the laptop. The laptop reassembles each frame, converts Bayer8 to RGB, runs YOLO, displays detections, and writes one CSV row per detected box. Neural inference stays on the laptop.

## Laptop receiver

The laptop's wired adapter is currently using `169.254.80.25/16`, matching the sender's link-local broadcast network. Start the receiver from the repository folder before starting the Zybo:

```powershell
python host\zybo_live_detect.py --bind 0.0.0.0 --port 5005 --model runs\indoor\homeobjects3k_yolo11n_320\weights\best.pt --phase BG
```

This opens a window titled `Zybo OV5647 live YOLO`; press `q` to stop. The live detection CSV is written to `build\zybo_live\detections.csv`. Add `--save-frames` to save annotated JPEGs. For headless reception, also pass `--no-display`. If Windows Firewall prompts, allow Python on the wired/private network.

## Start the Zybo sender

Keep the Ethernet cable connected directly between Zybo and laptop. With Vivado/Vitis 2025.2 installed and USB JTAG connected, open another PowerShell in the repository and run:

```powershell
$env:TEMP = Join-Path (Get-Location) 'build\hw_tmp'
$env:TMP = $env:TEMP
$env:XILINX_LOCAL_USER_DATA = 'NO'
New-Item -ItemType Directory -Force $env:TEMP | Out-Null
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' -eval "source fpga/start_ethernet_stream_jtag.tcl"
```

The script loads the existing HDMI-capable bitstream, initializes PS/DDR, enables camera power, configures the OV5647 for live VGA RAW10, then loads `build\ethernet_stream.elf`. The firmware captures three Bayer8 frame buffers and broadcasts ZCAM UDP packets from `169.254.80.26` to `169.254.255.255:5005`. HDMI is not required for laptop viewing. The current compiled ELF is a local build artifact and is not committed; the firmware source and protocol are in `firmware/`.

If direct Ethernet does not receive packets, verify the wired adapter has a `169.254.x.x` address with subnet mask `255.255.0.0`, allow inbound UDP port 5005, and confirm the Zybo LINK/ACT LED indicates link. The script reports a clear ARM/DAP error before programming when JTAG cannot access the processor.

## Current physical test status

The host application was tested with three loopback frames: all 660 UDP datagrams reassembled, YOLO processed each frame, and the output CSV was created. On the Zybo, XSCT currently sees the FPGA (`xc7z010`) but the ARM/DAP target fails with `AHB AP transaction error, DAP status 0x30000021`. Therefore the live physical camera-to-Ethernet-to-YOLO path could not be started in this run. Fully power-cycle the board and rerun the sender command; no received camera frames or real-time FPS are claimed until that physical test succeeds.
