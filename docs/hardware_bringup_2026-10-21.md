# Camera Rev 1.3 power-enable bring-up — 21 October 2026

The owner's new photos show **Raspberry Pi Camera Rev 1.3** on the front silkscreen, the ribbon seated in the camera connector, and an X1 oscillator component plus local regulator parts on the back. The photos themselves stay local because they also show hardware identifiers; they are not included in the public repository. [Raspberry Pi's camera connector documentation](https://www.raspberrypi.com/documentation/accessories/camera.html#camera-connector-pinout-15-pin) identifies pin 11 (`CAM_IO0`) as typically an active-high power enable and pin 12 as an auxiliary GPIO. Raspberry Pi has [not published the Rev 1.3 schematic](https://github.com/raspberrypi/documentation/issues/1324), so the board-side circuit is still inferred from the module identity, physical parts, and the electrical response below.

## Hardware change

- Added a one-bit AXI GPIO output, `camera_power`, at `0x41200000`. Its data reset value is zero.
- Routed `cam_power_en[0]` to Zybo FPGA pin G20, which is Pcam connector pin 11. Pcam pin 12/G19 remains unconnected.
- Rebuilt the XC7Z010 bitstream and XSA with Vivado 2025.2. Routed WNS is **+0.376 ns** with zero timing failures. DRC reports zero errors and 12 warnings. The new bitstream was loaded into volatile FPGA configuration only; board flash and SD storage were not written.
- The HDMI cable was disconnected during this test. HDMI is not required for camera detection.

## Physical test

1. Loaded the revised bitstream and initialized PS DDR using `fpga/start_hdmi_smoke_jtag.tcl`. The VDMA MM2S status was `0x00011000`, without transfer-error bits. This is a register-level check only, because no HDMI sink was attached.
2. Read the new GPIO output register at `0x41200000`: `0x00000000` before enable. Wrote zero, selected output, then wrote one; data readback became `0x00000001`. The AXI GPIO TRI register reads `0xFFFFFFFF` despite being configured as an all-output GPIO, so do not use that register readback as evidence of physical direction. The subsequent sensor response is the functional evidence that the camera became available.
3. Waited 50 ms, then requested two bytes from 7-bit I²C address `0x36`, starting at register `0x300A`. The TX FIFO drained to zero and the RX occupancy register read `1` (two bytes pending). Reading the RX FIFO returned **`0x56` then `0x47`**, matching the [OV5647 datasheet](https://cdn.sparkfun.com/datasheets/Dev/RaspberryPi/ov5647_full.pdf).
4. Reset AXI IIC to idle after reading the ID. Pcam pin 11 remains high until the FPGA is reconfigured or board power is removed.

This is the first verified on-board OV5647 chip-ID read. It establishes the I²C control path and the need to enable `CAM_IO0` for this camera setup. It does **not** establish CSI-2 data reception, frame capture, HDMI output, or Ethernet video streaming.

## Reproduce the ID check

From the repository root on the connected Windows laptop:

```powershell
python fpga/prepare_hdmi_smoke.py
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/start_hdmi_smoke_jtag.tcl
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/enable_camera_power_jtag.tcl
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/read_ov5647_id_jtag.tcl
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/read_camera_id_fifo_jtag.tcl
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/reset_iic_jtag.tcl
```

Expected ID bytes are `0x56`, `0x47`. The chip-ID probe script leaves data in the RX FIFO; the following script reads it. Do not run the FIFO-read script alone after a reset.

## VGA RAW10 and live CSI-2 packet test

The OV5647 register table in `fpga/ov5647_vga_regs.tcl` was extracted from a [pinned Linux OV5647 driver](https://github.com/torvalds/linux/blob/f47d223627f80cb7a1eb14c585fe6cb35de5e984/drivers/media/i2c/ov5647.c). Its GPL-2.0 attribution is retained in the generated file. The JTAG script applied 51 common entries, 28 VGA entries before stream-on, timing and stream registers, enabled sensor color bars, then wrote `0x0100=1`. All 89 I²C transactions completed without a transmit error. An earlier write and readback of software standby `0x0100=0` also succeeded.

Before stream-on, CSI interrupt status was `0x08021002`. After stream-on, the [CSI receiver](https://docs.amd.com/r/en-US/pg232-mipi-csi2-rx/Interrupt-Status-Register) reported `0x88021402`, including the Frame Received bit. Its packet count subsequently increased from **20,856 to 28,836** across a short observation window. The VC0 image information showed data type **`0x2B` (RAW10)** and byte count **`0x0320` (800 bytes)**, matching a 640-pixel RAW10 line. After clearing old sticky interrupt bits and observing a fresh window, the ISR was **`0x80020000`**: Frame Received and Stop State, without fresh SoT sync, ECC, CRC, or frame synchronization error bits. The [core status packet count](https://docs.amd.com/r/en-US/pg232-mipi-csi2-rx/Core-Status-Register) and [image information register](https://docs.amd.com/r/en-US/pg232-mipi-csi2-rx/Image-Information-1-Registers-VC0-to-VC15) meanings follow AMD PG232.

From the repository root after loading the current bitstream and enabling Pcam pin 11:

```powershell
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/configure_ov5647_vga_jtag.tcl
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/check_csi_frames_jtag.tcl
```

These results verify live CSI-2 packets and frame-end events from the attached camera. They do not yet prove that the custom RTL and VDMA wrote a complete frame into DDR or that the color-bar pixels are correct.

## First DDR capture probe

`fpga/capture_vga_probe_jtag.tcl` started the VDMA S2MM channel with three DDR frame buffers at `0x11000000`, `0x11080000`, and `0x11100000`, using 640-byte stride and 640×480 geometry. The first status was **`0x00015810`**. The [VDMA status bit definitions](https://docs.amd.com/r/en-US/pg020_axi_vdma/S2MM_VDMASR-S2MM-VDMA-Status-Register-Offset-34h) identify bits 14, 12, 11, and 4 as error IRQ, frame-count IRQ, start-of-frame late, and internal error respectively. This arose during capture startup in the middle of a running sensor stream. After clearing sticky bits and waiting 500 ms while capture continued, status was **`0x00011000`**: frame-count IRQ, with no error bits. S2MM was stopped before dumping DDR.

Sentinel words written to all three DDR buffers were overwritten by VDMA. Sparse samples across rows and columns varied in the expected test-bar pattern. `fpga/dump_vga_frame_jtag.tcl` read one stopped 640×480 frame (307,200 bytes) to an ignored build file, and `host/raw8_to_png.py` converted it to [this captured grayscale Bayer image](captures/ov5647_colorbars_640x480.png). The PNG was visually inspected on the laptop. The binary contains only `0x00` and `0xFF` pixel values because the sensor color-bar generator was enabled. This verifies a camera-to-CSI-to-custom-RTL-to-VDMA-to-DDR path for the test pattern. It does not yet verify natural-scene imaging, continuous buffer ownership, sustained FPS, HDMI display, or Ethernet streaming.

```powershell
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/capture_vga_probe_jtag.tcl
& 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' fpga/dump_vga_frame_jtag.tcl
python host/raw8_to_png.py build/capture/ov5647_colorbars_640x480.raw build/capture/ov5647_colorbars_640x480.png
```

## Next gate

Turn off the sensor test pattern, recover a natural-scene frame, then measure sustained frame rate and errors. Ethernet video firmware and the Python laptop viewer remain to be integrated. No HDMI cable is connected or needed for JTAG/DDR capture checks.
