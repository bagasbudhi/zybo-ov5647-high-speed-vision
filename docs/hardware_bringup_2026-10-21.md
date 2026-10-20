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

## Next gate

Apply a documented OV5647 VGA RAW10 mode, then verify CSI receiver status and actual DMA frames. Ethernet video firmware and the Python laptop viewer remain to be integrated. No HDMI cable is needed for those next control and capture checks.
