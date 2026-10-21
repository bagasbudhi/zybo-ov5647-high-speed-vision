# Board bring-up and remaining software

The first physical session is recorded in [hardware_bringup_2026-10-20.md](hardware_bringup_2026-10-20.md). The [21 October bring-up](hardware_bringup_2026-10-21.md) added Pcam pin-11 camera power enable, read OV5647 chip ID `0x5647`, and confirmed VGA RAW10 CSI-2 packets. The current milestone adds Bayer-to-RGB and ROI RTL, then captures a color-bar frame from DDR over JTAG. HDMI playback was started; visual confirmation on the TV is still needed. A USB HDMI capture device is needed to view Zybo HDMI on a laptop whose HDMI connector is output-only.

## What exists now

- The hardware design includes CSI RX, RAW10-to-Bayer8 conversion, frame/edge counters, VDMA write/read through DDR, Bayer-to-RGB conversion, ROI detection, VGA timing, Digilent HDMI TX, AXI IIC, and the Zynq PS preset. Check `test_results.md` for the latest build status before programming.
- `build/system/zybo_camera_system.xsa` contains hardware handoff for Vitis. The bitstream is a separate file because direct in-process Vivado implementation did not create a project implementation run from which `write_hw_platform -include_bit` can retrieve it.
- `firmware/zcam_protocol.c` packages Bayer8 frames in the same UDP format consumed by `host/viewer.py`. It cross-compiles for Cortex-A9, but is **not connected to a DMA/Ethernet application** yet.

## Before programming with the camera attached

1. The photos identify a Raspberry Pi Camera Rev 1.3 with an on-board X1 oscillator. With the board powered off, check the Zybo Pcam FFC contacts face the board's top edge, away from its center, and close the off-white latch fully, as shown in [Digilent's board manual](https://digilent.com/reference/_media/reference/programmable-logic/zybo-z7/zybo-z7_rm.pdf). The current bitstream drives Pcam pin 11/G20 only through software-controlled AXI GPIO; pin 12/G19 remains unused. The successful chip-ID read after enabling pin 11 is documented in the 21 October log.
2. Connect board USB JTAG/UART to the laptop for programming and logs. HDMI is optional during camera identification and CSI/DDR capture checks. For a visible HDMI test later, connect **Zybo HDMI OUT** to an external HDMI monitor or a USB HDMI capture device attached to the laptop. The MSI Bravo 15 C7VFK built-in HDMI port is output-only. The Zybo HDMI IN remains unused. The Ethernet cable is connected, but the Python UDP viewer requires board Ethernet firmware.
3. To start live camera capture and HDMI playback over JTAG, run `enable_camera_power_jtag.tcl`, `configure_ov5647_vga_jtag.tcl`, and `start_camera_hdmi_jtag.tcl` in that order after programming the bitstream and initializing PS/DDR. `start_hdmi_smoke_jtag.tcl` initializes PS/DDR and starts the known HDMI smoke frame. These scripts perform volatile register writes only; they do not write board flash or SD storage. HDMI was started, but a visible image on the display still needs confirmation. The XSA does not embed the bitstream, so select the separate `.bit` when programming.
4. Enable camera power through AXI GPIO `0x41200000`, allow at least 20 ms, and read OV5647 chip ID **0x5647** at register **0x300A** (two bytes over consecutive addresses) before writing any mode table. The successful JTAG sequence and readback are in the 21 October log. The upstream [Linux OV5647 driver](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c) documents the ID and a 20 ms wait after power-down release/reset before I2C access.
5. Run `fpga/configure_ov5647_vga_jtag.tcl` to program the tested 640x480 RAW10 sensor mode, then `fpga/check_csi_frames_jtag.tcl` to observe packets and fresh interrupt flags. The Linux driver reports a 145.8333 MHz VGA link frequency, corresponding to about 291.667 Mb/s per lane. The Vivado receiver is configured to nominal 292 Mb/s per lane. Live packets, frame-end events, RAW10 type and 800-byte line size have been observed.
6. Run `fpga/capture_vga_probe_jtag.tcl` to capture three DDR buffers, then `fpga/dump_vga_frame_jtag.tcl` and `host/bayer8_to_rgb.py` to create an RGB PNG. The current color-bar frame was recovered at 640 × 480. The HDMI read path now demosaics Bayer8 and counts bright ROI pixels. AXI GPIO metrics are in the XSA address map, but XSCT metric readback faulted at `0x41210000`; debug before claiming telemetry is verified.
7. Build a Zynq software application in Vitis from the XSA. It must initialize IIC and sensor, CSI RX, the VTC and both VDMA channels, then manage buffer ownership so the display does not read a frame while DMA is writing it. The bitstream alone cannot start live video.
8. Check for a stable 640 × 480 color image on a monitor or USB capture device. Measure complete-frame FPS, CSI errors, VDMA errors and routed timing under the actual sensor mode. Do not describe the host reconstructed PNG as an HDMI screenshot.

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
