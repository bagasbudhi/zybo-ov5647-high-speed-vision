# Zybo Z7-10 OV5647 Bayer vision demo

This portfolio project receives VGA RAW10 from a Raspberry Pi Camera Rev 1.3 / OV5647 over two lane MIPI CSI-2, converts it to Bayer8, writes frames to DDR with AXI VDMA, then reads them through custom Bayer-to-RGB and bright-region RTL before HDMI TX.

**Milestone status (21 October 2026):** Vivado 2025.2 rebuilt and routed the XC7Z010 design. The new FPGA image was programmed over JTAG; OV5647 640×480 color-bar capture and HDMI playback were started; the CSI packet counter advanced; fresh S2MM and MM2S status were both `0x00011000`. A 307,200-byte Bayer8 frame was dumped from DDR over JTAG and reconstructed as the shareable RGB PNG below. Detector readback over JTAG reported 76,800 bright pixels in the center ROI and a bounding box spanning x=160…479, y=120…359. The HDMI signal was not visually inspected at the TV during this build.

![OV5647 Bayer capture reconstructed to RGB](docs/captures/ov5647_colorbars_demosaiced_640x480.png)

The image is reconstructed on the laptop from the board's DDR Bayer8 frame dump using the repository's Python reference for the same causal interpolation used in RTL. It demonstrates camera reception, DDR capture, and the Bayer interpretation; it is not a TV/HDMI screenshot. The test image was made with the sensor's color-bar pattern enabled. The JTAG raw dump stays under ignored `build/capture/` and is not committed.

## Hardware path

```text
OV5647 RAW10 → MIPI CSI-2 RX → RAW10/Bayer8 + frame monitor → AXI VDMA S2MM → DDR
                                                                                ↓
HDMI OUT ← rgb2dvi ← Video Out/VTC ← ROI detector ← Bayer-to-RGB ← AXI VDMA MM2S
```

The MIPI physical receiver and CSI-2 packet receiver use AMD IP. The custom RTL contribution performs stream demosaicing, frame checks, bright-pixel counting, and bounding-box tracking.

### Bayer-to-RGB

`rtl/axis_bayer_demosaic.v` defaults to BGGR. It uses the current, left, upper, and upper-left Bayer samples to estimate missing channels, averages available samples of each color, and uses the current sample at borders where a channel is unavailable. This is a compact causal approximation that needs one 8-bit line buffer and preserves AXI ready/valid and SOF/EOL sidebands. It is not a full symmetric bilinear filter. The current capture path discards the low two bits of RAW10 when forming Bayer8.

### Measurable detection

`rtl/axis_bright_roi_detector.v` passes RGB through and computes luma as `(R + 2G + B) / 4`. It counts pixels at or above 32 in the central 320×240 region (x=160…479, y=120…359) and latches the count and bounding box at the end of each valid 640×480 frame. Metrics are connected to AXI GPIO for PS readback. The RTL behavior is simulated; GPIO metric readback was not confirmed over JTAG in this run.

See [register map and measurement method](docs/bayer_rgb_detection.md), [verification results](docs/test_results.md), and [hardware bring-up log](docs/hardware_bringup_2026-10-21.md).

## Build and test

Run in PowerShell from the repository root:

```powershell
python -m unittest discover -s host -p 'test_*.py' -v

$sim = Join-Path (Get-Location) 'build\sim_bayer'
New-Item -ItemType Directory -Force $sim | Out-Null
Push-Location $sim
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xvlog.bat' -sv `
  ..\..\rtl\axis_bayer_demosaic.v `
  ..\..\rtl\axis_bright_roi_detector.v `
  ..\..\sim\tb_axis_bayer_vision.sv
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xelab.bat' tb_axis_bayer_vision -s tb_axis_bayer_vision
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xsim.bat' tb_axis_bayer_vision -runall
Pop-Location
```

The full design build and XSA export are `fpga/build_system.tcl` and `fpga/export_xsa.tcl`. The generated deliverables are copied to `artifacts/`. Review [routed timing and utilization](docs/system_routed_timing.txt) and [DRC](docs/system_drc.txt) after a rebuild. The build uses Vivado 2025.2 and the local Digilent `rgb2dvi` IP under `fpga/ip_repo`.

## Board setup

Connect the camera's 15-pin ribbon to the Zybo Pcam connector with the board powered off, and connect Zybo **HDMI OUT** to a monitor or capture device. USB JTAG is used for configuration and the frame dump. The HDMI path is started through volatile JTAG register writes; there is no boot firmware that autonomously configures the camera yet. The Ethernet cable is not used by this milestone, and Ethernet video streaming is not implemented.

Useful scripts:

- `fpga/enable_camera_power_jtag.tcl` enables the Pcam power GPIO.
- `fpga/configure_ov5647_vga_jtag.tcl` configures the tested VGA RAW10 color-bar mode.
- `fpga/start_camera_hdmi_jtag.tcl` starts VDMA capture and HDMI playback.
- `fpga/check_camera_hdmi_jtag.tcl` checks fresh CSI/VDMA status.
- `fpga/capture_vga_probe_jtag.tcl` captures then stops S2MM; `fpga/dump_vga_frame_jtag.tcl` saves the Bayer8 frame under ignored `build/capture/`.
- `host/bayer8_to_rgb.py` converts a raw dump to RGB PNG, for example:

  ```powershell
  python host\bayer8_to_rgb.py build\capture\ov5647_colorbars_640x480.raw docs\captures\frame.png --phase BG
  ```

The HDMI output was started but still needs visual confirmation on an external display. A laptop HDMI connector is commonly output-only; a USB HDMI capture device is required to view Zybo HDMI on such a laptop.

## Portfolio framing

This demonstrates MIPI CSI-2 camera bring-up, AXI4-Stream processing, line-buffered RTL, frame-level measurement, DDR/VDMA integration, HDMI output integration, simulation, and timing closure on a resource-constrained Zynq-7000 device. It is a camera-interface/vision subsystem example relevant to automotive camera and ADAS interface roles. Do not describe the detector as a validated automotive perception function; it is a threshold-and-bounding-box demonstration.
