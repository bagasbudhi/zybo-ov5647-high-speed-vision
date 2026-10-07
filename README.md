# Zybo Z7-10 high speed camera interface portfolio project

**Status (7 October 2026):** The Z7-10 CSI-2 to custom RTL to DDR frame buffer to HDMI OUT hardware system was synthesized, routed, and built into a bitstream. Routed WNS is +0.843 ns; DRC reports no errors and 12 warnings. **Live OV5647-to-HDMI video is not yet demonstrated:** sensor clock/power control, sensor register setup, VDMA initialization software, and physical validation remain. The bitstream alone will not display camera video. The optional Python UDP viewer and synthetic sender pass protocol tests.

Start with [the verified results](docs/test_results.md), [hardware inventory](docs/hardware_inventory.md), and [board bring-up steps](docs/bringup.md). The checked-in bitstream and Vitis handoff are `artifacts/zybo_camera_system.bit` and `artifacts/zybo_camera_system.xsa`; neither has been validated on physical hardware. The generated Vivado project is `build/system/zybo_camera_system.xpr`. `fpga/build_system.tcl` recreates the hardware design and bitstream; `fpga/export_xsa.tcl` recreates the XSA. The smaller `fpga/build.tcl` builds the isolated custom RTL and CSI IP for inspection and comparison.

Build a demonstrable path from the OV5647 two lane MIPI CSI-2 camera on a Zybo Z7-10 to the laptop's confirmed HDMI input. The FPGA fabric owns camera reception, frame accounting, a small real-time vision block, DDR frame buffering, and HDMI video output. The Zynq processor must configure the sensor and VDMA. Ethernet and the Python UDP viewer remain optional diagnostics.

## Why this project

The project demonstrates high speed serial reception, AXI4-Stream video, clock domain crossing, backpressure and loss handling, memory transfer, hardware and software integration, verification, and measured throughput. A parameterized RTL edge or motion metric supplies a clear, independently tested contribution. These are relevant skills for automotive camera/ADAS SoC work. For a V2X focused role, document that this is an interface and verification portfolio piece, not a V2X modem.

## Physical connections and laptop viewing

```text
OV5647 module -- 15-pin ribbon / 2-lane CSI-2 --> Zybo Pcam port
Zybo HDMI OUT -- HDMI cable --> laptop HDMI IN
Zybo USB JTAG/UART -- USB --> laptop Vivado programming and logs
Optional: Zybo Ethernet -- cable / LAN --> laptop Python receiver
```

Use the Zybo's **HDMI OUT**, not HDMI IN. The user reports that the laptop has **HDMI IN**, so its HDMI input viewer or capture application should display the Zybo signal. Ethernet has no role in the primary live-video path; it can carry optional debug frames and metrics. The Python UDP viewer is for that optional Ethernet path, not for HDMI capture.

## Baseline architecture

```text
OV5647 RAW10, 2 CSI-2 lanes
  -> AMD MIPI D-PHY / CSI-2 RX IP, if supported by installed Vivado and Z7-10
  -> AXI4-Stream video (record exact packing, SOF, EOL and clock)
  -> custom RTL frame monitor + optional streaming edge/motion metric
  -> AXI VDMA write -> PS DDR frame buffers -> AXI VDMA read
  -> Bayer8 luma-to-RGB888 RTL -> AXI4-Stream to Video Out + VTC
  -> Digilent rgb2dvi IP -> Zybo HDMI OUT -> laptop HDMI IN

Zynq ARM software is still required for sensor I2C, CSI control, and both VDMA channels. Ethernet and Python are optional diagnostics. The initial HDMI image is grayscale Bayer samples; color demosaicing is a later enhancement.
```

Keep the MIPI analog PHY and CSI-2 packet receiver as vendor IP. The portfolio RTL should be the stream processing and observability logic, written and verified by the project. Do not claim a hand-written PHY. If the installed IP is unavailable, unlicensed, does not implement on XC7Z010, or fails resource/timing gates, pause that hardware branch and document the result; do not silently switch to a Z7-20 design or claim camera reception.

## Hardware and software facts to verify first

1. Record the board revision, exact FPGA part, Vivado and Vitis versions, installed board files, OS, cable/camera module markings, and power source. Do not assume an OV5647 clone has the same oscillator and power-down circuit as the official Pi module.
2. Check the camera connector orientation, pin mapping, 3.3 V supply, I2C pull-ups, GPIO reset/power-down, and whether the camera module supplies its own XCLK oscillator. Find the exact module schematic if possible. Never drive an unknown GPIO or apply an external clock until its circuit is known.
3. In the installed Vivado, check CSI-2 RX IP availability, license status, two-lane RAW10 support, device support, implementation results, and bitstream generation. Licensing statements vary by IP and version; the installed tool result is authoritative.
4. The board manual reports the Pcam link was tested to **672 Mb/s per lane**. Keep the selected sensor mode and programmed link rate within that board-validated ceiling. Do not infer the lane rate from active pixel payload alone; use the sensor PLL/configuration and verify with the receiver status.
5. Start at **640x480 RAW10**, using a proven OV5647 mode and a modest frame rate. The upstream Linux OV5647 driver documents a VGA RAW10 mode and link-frequency settings, but its tables still need adaptation and verification for this camera module. Treat 720p/1080p as stretch targets after measured closure.
6. Start with a known frame in DDR so HDMI timing and the laptop input can be checked independently of camera bring-up.

## Work packages and acceptance gates

| Stage | Implementation | Evidence required |
| --- | --- | --- |
| 0. Inventory | Inspect local Vivado/Vitis, board, sensor, port wiring, IP catalog, license and published sources. | `docs/hardware_inventory.md`, photos/labels where available, explicit go/no-go for CSI RX on XC7Z010. |
| 1. HDMI display | Add DDR readback, VGA video timing and HDMI TX; use a known frame for independent display bring-up. | Block design validation, bitstream, timing/DRC, visible test frame on laptop HDMI input. |
| 2. RTL core | Write parameterized AXI4-Stream frame checker with frame/line/pixel counters, malformed-frame and stall counters, optional simple edge or ROI activity score. Define AXI-Lite register map or simpler exposed status interface. | Self-checking simulations for SOF/EOL, reset, backpressure, truncated/oversize frames and metric math; synthesis/utilization report. |
| 3. FPGA integration | Tcl-built Vivado project for exact Z7-10 part; PS DDR/UART/IIC, custom RTL, VDMA read/write and HDMI output. | Clean project recreation, address map, bitstream, utilization and timing reports. |
| 4. Sensor bring-up | Confirm clock/power-down, read OV5647 chip ID over I2C, apply documented RAW10 mode, confirm D-PHY/CSI lock and nonzero valid frame count. | UART register dump, receiver status, frame-size statistics, recovered sample frame. |
| 5. Live display | PS firmware initializes camera and both VDMA channels, manages frame buffers, and starts video timing. | Live laptop HDMI screenshot/video, FPS and error counters over 5 minutes, end-to-end latency method and result. |
| 6. Portfolio | Architecture diagram, design choices, test summary, timing/utilization, measured lane and network bandwidth, limitations, 60–90 second demo, resume bullets. | Reproducible build/run instructions and honest result table with tested vs planned items. |

Implement stages in order. A later stage may remain blocked by physical access or IP constraints while earlier simulated work still has value. Preserve the distinction between simulation, synthesis, and actual on-board validation.

## Performance and memory budget

- Active VGA RAW10 payload: `640 × 480 × 10 × 30 = 92.16 Mb/s` at 30 fps; `184.32 Mb/s` at 60 fps, before CSI-2 overhead/blanking.
- Unpacked 8-bit VGA frames: `307,200 bytes/frame`, or `9.216 MB/s` at 30 fps. Two or three DDR buffers are enough for initial decoupling, subject to DMA stride/alignment.
- The initial HDMI path expands unpacked 8-bit Bayer samples to grayscale RGB888. It discards two low RAW10 bits. Retain 10-bit capture and add demosaicing when feasible; identify the Bayer order and any loss in the portfolio.
- For optional Ethernet diagnostics, use MTU-safe UDP chunks, frame/chunk IDs, sequence checking, a completion timeout, and a drop-oldest policy. Report complete frames only.
- A 5MP full-frame mode is outside the first milestone. Do not label a VGA implementation as 5MP streaming merely because the sensor has 5MP pixels.

## Suggested repository layout

```text
zybo-ov5647-high-speed-vision/
  README.md
  CODEX_BUILD_PROMPT.md
  artifacts/zybo_camera_system.bit
  artifacts/zybo_camera_system.xsa
  docs/architecture.md
  docs/hardware_inventory.md
  docs/register_map.md
  docs/test_results.md
  rtl/axis_frame_monitor.sv
  rtl/axis_raw10_to_bayer8.sv
  rtl/axis_vision_pipeline.v
  rtl/axis_gray_to_rgb.v
  sim/tb_axis_frame_monitor.sv
  sim/tb_axis_vision_pipeline.v
  fpga/build.tcl
  fpga/build_system.tcl
  fpga/export_xsa.tcl
  fpga/pcam_system.xdc
  fpga/hdmi_out.xdc
  fpga/ip_repo/                 # Digilent rgb2dvi + TMDS, licensed source
  fpga/board_files/zybo-z7-10/A.0/...
  firmware/zcam_protocol.c
  firmware/zcam_protocol.h
  firmware/hdmi_smoke.c
  firmware/...
  host/viewer.py
  host/protocol.py
  host/demo_sender.py
  host/test_protocol.py
```

## Run the delivered parts

```powershell
cd 'path\to\zybo-ov5647-high-speed-vision'
python -m unittest discover -s host -p 'test_*.py' -v
$env:XILINX_LOCAL_USER_DATA='NO'
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' -mode batch -nojournal -nolog -source 'fpga\build.tcl'
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' -mode batch -nojournal -nolog -source 'fpga\build_system.tcl'
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' -mode batch -nojournal -nolog -source 'fpga\export_xsa.tcl'
```

For the HDMI display smoke test, follow `docs/bringup.md` to build `firmware/hdmi_smoke.c` as a Vitis standalone application, program the `.bit`, run the ELF and select HDMI input on the laptop. For optional UDP viewer testing, install `host/requirements.txt` and run `python host/viewer.py`, then `python host/demo_sender.py` in another terminal. That local synthetic test does not require the Zybo. Correct Bayer ordering for the physical sensor remains to be established.

## Sources and limits

- [Digilent Zybo Z7 reference manual](https://digilent.com/reference/_media/reference/programmable-logic/zybo-z7/zybo-z7_rm.pdf): exact board part, Pcam pinout, 672 Mb/s/lane validated speed, HDMI TX/RX, Z7-10 resource limits.
- [AMD MIPI CSI-2 Receiver product guide](https://docs.amd.com/r/5.3-English/pg232-mipi-csi2-rx/Configuration-Tab): receiver format, lanes, and device-dependent configuration. Match the guide to the installed IP version.
- [Linux OV5647 sensor driver](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c): reference sensor modes and register sequencing. Verify compatibility and observe its license before reusing code.
- [Digilent Z7-20 Pcam 5C demo](https://github.com/Digilent/Zybo-Z7-20-pcam-5c): architectural reference only; it targets a larger board and an OV5640 sensor, so it is not a drop-in Z7-10/OV5647 project.
- [Digilent Z7-10 HDMI demo](https://github.com/Digilent/Zybo-Z7-10-HDMI): reference for the board's HDMI TX path.

The linked job postings were not readable through the available web fetch during planning. The portfolio alignment above is based on [BOS's ADAS/automotive products](https://www.bos-semi.com/product) and [RANIX's V2X/automotive focus](https://ranix.co.kr/en-CEO), rather than a claim about the postings' exact requirements.


