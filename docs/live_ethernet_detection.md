# Live Zybo Ethernet detection

This path sends 640x480 Bayer8 frames from the OV5647/VDMA DDR buffers as CRC-protected UDP packets to the laptop. The laptop reassembles each frame, converts Bayer8 to RGB, runs YOLO, displays detections, and writes one CSV row per detected box. Neural inference stays on the laptop.

## Laptop receiver

The laptop's wired adapter is currently using `169.254.80.25/16`, matching the sender's link-local broadcast network. Start the receiver from the repository folder before starting the Zybo:

```powershell
python host\zybo_live_detect.py --bind 0.0.0.0 --port 5005 --model runs\indoor\homeobjects3k_yolo11n_320\weights\best.pt --phase BG
```

This opens a window titled `Zybo OV5647 live YOLO`; press `q` to stop. The live detection CSV is written to `build\zybo_live\detections.csv`. Add `--save-frames` to save annotated JPEGs. For headless reception, also pass `--no-display`. If Windows Firewall prompts, allow Python on the wired/private network.

The current Windows Firewall policy blocks inbound traffic and is centrally managed. The end-to-end receiver needs an inbound UDP 5005 allow rule limited to Zybo IP `169.254.80.26`.

## Start the Zybo sender

Keep the Ethernet cable connected directly between Zybo and laptop. With Vivado/Vitis 2025.2 installed and USB JTAG connected, open another PowerShell in the repository and run:

```powershell
python fpga\prepare_hdmi_smoke.py
$env:TEMP = Join-Path (Get-Location) 'build\hw_tmp'
$env:TMP = $env:TEMP
$env:XILINX_LOCAL_USER_DATA = 'NO'
New-Item -ItemType Directory -Force $env:TEMP | Out-Null
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' -eval "source fpga/start_ethernet_stream_jtag.tcl"
```

The script loads the existing HDMI-capable bitstream, initializes PS/DDR and the HDMI pixel clock, enables camera power, configures the OV5647 for live VGA RAW10, then loads `build\ethernet_stream.elf`. The firmware captures three Bayer8 frame buffers and broadcasts ZCAM UDP packets from `169.254.80.26` to `169.254.255.255:5005`. An HDMI cable is not required for laptop viewing; the design uses its pixel clock internally. The current compiled ELF is a local build artifact and is not committed; the firmware source and protocol are in `firmware/`.

If direct Ethernet does not receive packets, verify the wired adapter has a `169.254.x.x` address with subnet mask `255.255.0.0`, allow inbound UDP port 5005, and confirm the Zybo LINK/ACT LED indicates link. The script reports a clear ARM/DAP error before programming when JTAG cannot access the processor.

## Current physical test status

The host application was tested with three loopback frames: all 660 UDP datagrams reassembled, YOLO processed each frame, and the output CSV was created. After a full Zybo power cycle, XSCT found both Cortex-A9 targets, configured the OV5647, and ran the Ethernet firmware. The board UART reported consecutive `FRAME=... chunks=220 status=00011000` messages and `link=1`; S2MM status was clean after starting the HDMI/VTC pixel-clock path. The laptop receiver still got zero datagrams: Windows Firewall is set to block inbound traffic and the profile is centrally managed. Thus physical camera capture and UDP transmission are running, but end-to-end laptop reception and displayed live YOLO detections remain unverified until an inbound UDP rule is approved and applied. No real camera detection accuracy or sustained FPS is claimed yet.
