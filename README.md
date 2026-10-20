# Zybo Z7-10 high speed camera interface portfolio project

**Status (21 October 2026):** The Z7-10 CSI-2 to custom RTL to DDR frame buffer to HDMI OUT hardware system was rebuilt with a software-controlled Camera Rev 1.3 power-enable output. Routed WNS is +0.376 ns; DRC reports no errors and 12 warnings. FPGA programming, PS DDR initialization, test-frame download, and VDMA register checks work on the connected board. **The OV5647 chip ID and live CSI-2 packets are now verified on hardware:** enabling Pcam pin 11 returned `0x5647`; a 640×480 RAW10 mode produced increasing packet counts, frame-end events, RAW10 data type `0x2B`, and 800-byte lines. DDR capture, visible HDMI output, and Ethernet streaming are not yet demonstrated. No HDMI cable is currently connected. The MSI Bravo 15 C7VFK laptop has HDMI output only, so later HDMI viewing needs an external monitor or USB capture device. Ethernet firmware remains unimplemented.

Start with [the verified results](docs/test_results.md), [the camera and CSI bring-up](docs/hardware_bringup_2026-10-21.md), [OV5647 datasheet checks](docs/ov5647_datasheet_notes.md), and [board bring-up steps](docs/bringup.md). The checked-in bitstream and Vitis handoff are `artifacts/zybo_camera_system.bit` and `artifacts/zybo_camera_system.xsa`. FPGA programming, DDR test-frame download, VDMA register checks, the sensor chip-ID read, and CSI packet reception were validated on the board; DDR camera frame capture has not been validated. The generated Vivado project is `build/system/zybo_camera_system.xpr`. `fpga/build_system.tcl` recreates the hardware design and bitstream; `fpga/export_xsa.tcl` recreates the XSA. The smaller `fpga/build.tcl` builds the isolated custom RTL and CSI IP for inspection and comparison.

Build a demonstrable path from the OV5647 two lane MIPI CSI-2 camera on a Zybo Z7-10 to a display or laptop application. The FPGA fabric owns camera reception, frame accounting, a small real-time vision block, DDR frame buffering, and HDMI video output. The Zynq processor must configure the sensor and VDMA. Ethernet transport and the Python UDP viewer need additional board firmware.

## Why this project

The project demonstrates high speed serial reception, AXI4-Stream video, clock domain crossing, backpressure and loss handling, memory transfer, hardware and software integration, verification, and measured throughput. A parameterized RTL edge or motion metric supplies a clear, independently tested contribution. These are relevant skills for automotive camera/ADAS SoC work. For a V2X focused role, document that this is an interface and verification portfolio piece, not a V2X modem.

## Physical connections and laptop viewing

```text
OV5647 module -- 15-pin ribbon / 2-lane CSI-2 --> Zybo Pcam port
Zybo HDMI OUT -- HDMI cable --> external monitor or USB HDMI capture device --> laptop
Zybo USB JTAG/UART -- USB --> laptop Vivado programming and logs
Zybo Ethernet -- cable / LAN --> laptop Python receiver (after board UDP firmware is built)
```

Use the Zybo's **HDMI OUT** for a monitor or USB HDMI capture device. The MSI Bravo 15 C7VFK laptop's built-in HDMI port is an output, so a direct HDMI cable cannot display the Zybo signal there. The Python UDP viewer receives frames over Ethernet after PS Ethernet firmware is implemented; it does not capture HDMI.

## Baseline architecture

```text
OV5647 RAW10, 2 CSI-2 lanes
  -> AMD MIPI D-PHY / CSI-2 RX IP, if supported by installed Vivado and Z7-10
  -> AXI4-Stream video (record exact packing, SOF, EOL and clock)
  -> custom RTL frame monitor + optional streaming edge/motion metric
  -> AXI VDMA write -> PS DDR frame buffers -> AXI VDMA read
  -> Bayer8 luma-to-RGB888 RTL -> AXI4-Stream to Video Out + VTC
  -> Digilent rgb2dvi IP -> Zybo HDMI OUT -> monitor or USB HDMI capture

Zynq ARM software is still required for sensor I2C, CSI control, and both VDMA channels. Ethernet and Python are optional diagnostics. The initial HDMI image is grayscale Bayer samples; color demosaicing is a later enhancement.
```

Keep the MIPI analog PHY and CSI-2 packet receiver as vendor IP. The portfolio RTL should be the stream processing and observability logic, written and verified by the project. Do not claim a hand-written PHY. If the installed IP is unavailable, unlicensed, does not implement on XC7Z010, or fails resource/timing gates, pause that hardware branch and document the result; do not silently switch to a Z7-20 design or claim camera reception.

## Hardware and software facts to verify first

1. Record the board revision, exact FPGA part, Vivado and Vitis versions, installed board files, OS, cable/camera module markings, and power source. Do not assume an OV5647 clone has the same oscillator and power-down circuit as the official Pi module.
2. Check the camera connector orientation, pin mapping, 3.3 V supply, I2C pull-ups, GPIO reset/power-down, and whether the camera module supplies its own XCLK oscillator. Find the exact module schematic if possible. Never drive an unknown GPIO or apply an external clock until its circuit is known.
3. In the installed Vivado, check CSI-2 RX IP availability, license status, two-lane RAW10 support, device support, implementation results, and bitstream generation. Licensing statements vary by IP and version; the installed tool result is authoritative.
4. The board manual reports the Pcam link was tested to **672 Mb/s per lane**. Keep the selected sensor mode and programmed link rate within that board-validated ceiling. Do not infer the lane rate from active pixel payload alone; use the sensor PLL/configuration and verify with the receiver status.
5. Start at **640x480 RAW10**, using a proven OV5647 mode and a modest frame rate. The upstream Linux OV5647 driver documents a VGA RAW10 mode and link-frequency settings, but its tables still need adaptation and verification for this camera module. Treat 720p/1080p as stretch targets after measured closure.
6. Start with a known frame in DDR so HDMI timing and a monitor/capture input can be checked independently of camera bring-up.

## Work packages and acceptance gates

| Stage | Implementation | Evidence required |
| --- | --- | --- |
| 0. Inventory | Inspect local Vivado/Vitis, board, sensor, port wiring, IP catalog, license and published sources. | `docs/hardware_inventory.md`, photos/labels where available, explicit go/no-go for CSI RX on XC7Z010. |
| 1. HDMI display | Add DDR readback, VGA video timing and HDMI TX; use a known frame for independent display bring-up. | Block design validation, bitstream, timing/DRC, visible test frame on an external monitor or USB capture. |
| 2. RTL core | Write parameterized AXI4-Stream frame checker with frame/line/pixel counters, malformed-frame and stall counters, optional simple edge or ROI activity score. Define AXI-Lite register map or simpler exposed status interface. | Self-checking simulations for SOF/EOL, reset, backpressure, truncated/oversize frames and metric math; synthesis/utilization report. |
| 3. FPGA integration | Tcl-built Vivado project for exact Z7-10 part; PS DDR/UART/IIC, custom RTL, VDMA read/write and HDMI output. | Clean project recreation, address map, bitstream, utilization and timing reports. |
| 4. Sensor bring-up | Confirm clock/power-down, read OV5647 chip ID over I2C, apply documented RAW10 mode, confirm D-PHY/CSI lock and nonzero valid frame count. | UART register dump, receiver status, frame-size statistics, recovered sample frame. |
| 5. Live display | PS firmware initializes camera and both VDMA channels, manages frame buffers, and starts video timing. | Live monitor/capture image or Ethernet viewer screenshot, FPS and error counters over 5 minutes, end-to-end latency method and result. |
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

For the HDMI display smoke test, follow `docs/bringup.md` to build `firmware/hdmi_smoke.c` as a Vitis standalone application, program the `.bit`, run the ELF, and view Zybo HDMI OUT on an external monitor or USB HDMI capture device. For local UDP viewer testing, install `host/requirements.txt` and run `python host/viewer.py`, then `python host/demo_sender.py` in another terminal. That synthetic test does not require the Zybo. Correct Bayer ordering for the physical sensor remains to be established.

## Sources and limits

- [Digilent Zybo Z7 reference manual](https://digilent.com/reference/_media/reference/programmable-logic/zybo-z7/zybo-z7_rm.pdf): exact board part, Pcam pinout, 672 Mb/s/lane validated speed, HDMI TX/RX, Z7-10 resource limits.
- [AMD MIPI CSI-2 Receiver product guide](https://docs.amd.com/r/5.3-English/pg232-mipi-csi2-rx/Configuration-Tab): receiver format, lanes, and device-dependent configuration. Match the guide to the installed IP version.
- [Linux OV5647 sensor driver](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c): reference sensor modes and register sequencing. Verify compatibility and observe its license before reusing code.
- [Digilent Z7-20 Pcam 5C demo](https://github.com/Digilent/Zybo-Z7-20-pcam-5c): architectural reference only; it targets a larger board and an OV5640 sensor, so it is not a drop-in Z7-10/OV5647 project.
- [Digilent Z7-10 HDMI demo](https://github.com/Digilent/Zybo-Z7-10-HDMI): reference for the board's HDMI TX path.

The linked job postings were not readable through the available web fetch during planning. The portfolio alignment above is based on [BOS's ADAS/automotive products](https://www.bos-semi.com/product) and [RANIX's V2X/automotive focus](https://ranix.co.kr/en-CEO), rather than a claim about the postings' exact requirements.


