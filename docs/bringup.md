# Board bring-up and remaining software

## What exists now

- The hardware design includes CSI RX, RAW10-to-Bayer8 conversion, frame/edge counters, VDMA write/read through DDR, grayscale RGB expansion, VGA timing, Digilent HDMI TX, AXI IIC, and the Zynq PS preset. Check `test_results.md` for the latest build status before programming.
- `build/system/zybo_camera_system.xsa` contains hardware handoff for Vitis. The bitstream is a separate file because direct in-process Vivado implementation did not create a project implementation run from which `write_hw_platform -include_bit` can retrieve it.
- `firmware/zcam_protocol.c` packages Bayer8 frames in the same UDP format consumed by `host/viewer.py`. It cross-compiles for Cortex-A9, but is **not connected to a DMA/Ethernet application** yet.

## Before programming with the camera attached

1. Confirm Zybo PCB revision, camera module maker/revision, ribbon orientation, oscillator and whether Pcam GPIO (board pins G19/G20) controls clock and power-down. The current bitstream does not drive those two signals. Do not infer their function from the sensor name alone.
2. Connect board USB JTAG/UART to the laptop for programming and logs. Connect **Zybo HDMI OUT** to the laptop's confirmed **HDMI IN**. Open the laptop's HDMI input viewing application and select that input. The Zybo HDMI IN remains unused. Ethernet is optional for the Python UDP viewer or diagnostics.
3. Before camera setup, create a Vitis standalone Cortex-A9 application from `zybo_camera_system.xsa`, add `firmware/hdmi_smoke.c`, reserve physical DDR `0x10000000` through `0x1004AFFF` for its frame buffer, and build its ELF. Program `zybo_camera_system.bit`, initialize the PS/DDR with the platform startup flow, and run the ELF. The app fills DDR with grayscale bars, flushes the cache, enables the VTC and starts VDMA MM2S. It cross-compiles but has **not** been run on hardware. If the laptop shows bars, the DDR-to-HDMI path works independently of the camera. The XSA does not embed the bitstream, so select the separate `.bit` when programming.
4. Confirm 3.3 V module power, I2C idle levels, and power/reset sequencing. Read OV5647 chip ID **0x5647** at register **0x300A** (16-bit read over consecutive addresses) before writing any mode table. The upstream [Linux OV5647 driver](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c) documents the ID and a 20 ms wait after power-down release/reset before I2C access.
5. Program a verified 640x480 RAW10 mode for the actual module. The Linux driver reports a 145.8333 MHz VGA link frequency, corresponding to about 291.667 Mb/s per lane. The Vivado receiver is configured to nominal 292 Mb/s per lane. Check D-PHY/CSI status, CRC/ECC counters, line length, SOF/EOL, and Bayer pattern before relying on images.
6. Configure VDMA S2MM and MM2S to use frame buffers in PS DDR, with 640-byte stride and 640 × 480 active pixels. The hardware converts four Bayer8 samples to a 32-bit AXI stream beat on write, then reads one byte per pixel for grayscale HDMI. Check byte order and cache handling with a known frame. The pipeline's frame/edge counters are currently fabric outputs without an AXI-Lite register slave; expose them through AXI GPIO or a custom register block before claiming software telemetry.
7. Build a Zynq software application in Vitis from the XSA. It must initialize IIC and sensor, CSI RX, the VTC and both VDMA channels, then manage buffer ownership so the display does not read a frame while DMA is writing it. The bitstream alone cannot start live video.
8. Check for a stable 640 × 480 image in the laptop HDMI input application. Measure complete-frame FPS, CSI errors, VDMA errors and routed timing under the actual sensor mode. The output is initially grayscale Bayer data, not demosaiced color.

Optional Ethernet path: set up PS GEM/lwIP, send completed frames with `zcam_send_frame`, and start `host/viewer.py --bind 0.0.0.0 --port 5005` on the laptop. This software path has not yet been integrated.

The smoke app's register sequence follows the [AMD AXI VDMA programming sequence](https://docs.amd.com/r/en-US/pg020_axi_vdma/Programming-Sequence) and [AMD VTC generator control](https://docs.amd.com/r/en-US/pg016_v_tc/Register-Descriptions). Its peripheral base addresses were checked against the generated XSA hardware handoff.

## Address map from generated hardware handoff

| Peripheral | Base address |
| --- | --- |
| AXI IIC (`camera_iic`) | `0x41600000` |
| AXI VDMA (`camera_vdma`) | `0x43000000` |
| CSI RX subsystem (`csi_rx`) | `0x43C00000` |

Confirm these values against the Vitis generated `xparameters.h` before using them. They are derived from the generated `system.hwh`, not hard-coded in the hardware Tcl script.

## Verification already completed

See [test_results.md](test_results.md). A successful bitstream does not establish that this particular OV5647 module powers up, that its lane rate is correct, or that the laptop has a usable Ethernet path.
