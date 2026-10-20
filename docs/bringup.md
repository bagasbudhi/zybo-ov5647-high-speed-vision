# Board bring-up and remaining software

The first physical session is recorded in [hardware_bringup_2026-10-20.md](hardware_bringup_2026-10-20.md). The [21 October bring-up](hardware_bringup_2026-10-21.md) added Pcam pin-11 camera power enable and obtained the correct OV5647 chip ID `0x5647`. Live CSI-2 capture is still unverified. Visible HDMI output needs an external monitor or USB HDMI capture device because the laptop's built-in HDMI port is output-only.

## What exists now

- The hardware design includes CSI RX, RAW10-to-Bayer8 conversion, frame/edge counters, VDMA write/read through DDR, grayscale RGB expansion, VGA timing, Digilent HDMI TX, AXI IIC, and the Zynq PS preset. Check `test_results.md` for the latest build status before programming.
- `build/system/zybo_camera_system.xsa` contains hardware handoff for Vitis. The bitstream is a separate file because direct in-process Vivado implementation did not create a project implementation run from which `write_hw_platform -include_bit` can retrieve it.
- `firmware/zcam_protocol.c` packages Bayer8 frames in the same UDP format consumed by `host/viewer.py`. It cross-compiles for Cortex-A9, but is **not connected to a DMA/Ethernet application** yet.

## Before programming with the camera attached

1. The photos identify a Raspberry Pi Camera Rev 1.3 with an on-board X1 oscillator. With the board powered off, check the Zybo Pcam FFC contacts face the board's top edge, away from its center, and close the off-white latch fully, as shown in [Digilent's board manual](https://digilent.com/reference/_media/reference/programmable-logic/zybo-z7/zybo-z7_rm.pdf). The current bitstream drives Pcam pin 11/G20 only through software-controlled AXI GPIO; pin 12/G19 remains unused. The successful chip-ID read after enabling pin 11 is documented in the 21 October log.
2. Connect board USB JTAG/UART to the laptop for programming and logs. HDMI is optional during camera identification and CSI/DDR capture checks. For a visible HDMI test later, connect **Zybo HDMI OUT** to an external HDMI monitor or a USB HDMI capture device attached to the laptop. The MSI Bravo 15 C7VFK built-in HDMI port is output-only. The Zybo HDMI IN remains unused. The Ethernet cable is connected, but the Python UDP viewer requires board Ethernet firmware.
3. For the already tested JTAG smoke path, run `python fpga/prepare_hdmi_smoke.py` and then `& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/start_hdmi_smoke_jtag.tcl` from the repository root; see the physical bring-up log. Alternatively, build `firmware/hdmi_smoke.c` as a Vitis standalone Cortex-A9 application from `zybo_camera_system.xsa`, reserve physical DDR `0x10000000` through `0x1004AFFF` for its frame buffer, and run its ELF. The C app cross-compiles but has **not** been run on hardware. The JTAG path already programmed the `.bit`, initialized PS DDR, loaded a grayscale frame, enabled VTC, and started VDMA MM2S without writing board flash or SD storage. A visible image on a monitor/capture device is still required to validate HDMI output. The XSA does not embed the bitstream, so select the separate `.bit` when programming.
4. Enable camera power through AXI GPIO `0x41200000`, allow at least 20 ms, and read OV5647 chip ID **0x5647** at register **0x300A** (two bytes over consecutive addresses) before writing any mode table. The successful JTAG sequence and readback are in the 21 October log. The upstream [Linux OV5647 driver](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c) documents the ID and a 20 ms wait after power-down release/reset before I2C access.
5. Program a verified 640x480 RAW10 mode for the actual module. The Linux driver reports a 145.8333 MHz VGA link frequency, corresponding to about 291.667 Mb/s per lane. The Vivado receiver is configured to nominal 292 Mb/s per lane. Check D-PHY/CSI status, CRC/ECC counters, line length, SOF/EOL, and Bayer pattern before relying on images.
6. Configure VDMA S2MM and MM2S to use frame buffers in PS DDR, with 640-byte stride and 640 × 480 active pixels. The hardware converts four Bayer8 samples to a 32-bit AXI stream beat on write, then reads one byte per pixel for grayscale HDMI. Check byte order and cache handling with a known frame. The pipeline's frame/edge counters are currently fabric outputs without an AXI-Lite register slave; expose them through AXI GPIO or a custom register block before claiming software telemetry.
7. Build a Zynq software application in Vitis from the XSA. It must initialize IIC and sensor, CSI RX, the VTC and both VDMA channels, then manage buffer ownership so the display does not read a frame while DMA is writing it. The bitstream alone cannot start live video.
8. Check for a stable 640 × 480 image on a monitor, USB capture device, or implemented Ethernet viewer. Measure complete-frame FPS, CSI errors, VDMA errors and routed timing under the actual sensor mode. The output is initially grayscale Bayer data, not demosaiced color.

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
