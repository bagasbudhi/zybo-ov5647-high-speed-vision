# Physical bring-up log — 20 October 2026

## Connections observed

- Windows detects a Digilent FTDI USB serial/JTAG device; UART appears as COM11.
- Vivado Hardware Manager found a Digilent JTAG target and an `xc7z010` FPGA.
- The laptop's Realtek Ethernet adapter shows an active 1 Gbps link. It has a link-local address (`169.254.80.25`), so the Ethernet video application is not running on the board.
- The user connected Zybo HDMI OUT to the laptop's built-in HDMI port after the initial Ethernet-only setup. The laptop is an MSI Bravo 15 C7VFK. [MSI's model specification](https://storage-asset.msi.com/excelSku/ca/nb/Bravo%2015%20C7VFK-057CA%20.pdf) labels its port **HDMI-out**, so this cable connection cannot display Zybo video. An external HDMI monitor or USB HDMI capture device is needed to inspect the signal.

## HDMI path tested over JTAG

`fpga/start_hdmi_smoke_jtag.tcl` programmed `artifacts/zybo_camera_system.bit` into volatile FPGA configuration, initialized PS DDR using `ps7_init.tcl` from the XSA, downloaded `build/jtag/hdmi_bars_640x480.bin` to DDR at `0x10000000`, and started the VTC and VDMA MM2S read channel. It did not write board flash or SD storage.

Readback from `fpga/read_display_status_jtag.tcl`:

| Item | Observed value | Interpretation |
| --- | --- | --- |
| VTC control | `0x01FFEF07` | Video timing generator enabled. |
| VDMA MM2S control | `0x00010003` | Read channel running in circular mode. |
| VDMA MM2S status | `0x00011000` | Halted and transfer-error bits clear. |
| DDR first bar | `0x00000000` | Expected black pixels. |
| DDR second bar | `0x20202020` | Expected 32-level gray pixels. |
| DDR third bar | `0x40404040` | Expected 64-level gray pixels. |

This proves programming, DDR initialization, data download, and VDMA register operation. It does not prove HDMI electrical output or a visible image; that needs an external display or capture device.

## OV5647 I²C check

`fpga/read_ov5647_id_jtag.tcl` requested two bytes from OV5647 register `0x300A` at 7-bit I²C address `0x36`. No bytes arrived. AXI IIC reported interrupt status `0xD6`, including a transmit error, with RX occupancy zero. The controller was reset to idle afterward; status returned to `0xC0` (both FIFOs empty, bus idle).

Pcam SCL/SDA pins F20/F19 are constrained in the bitstream. The module's power-enable/clock wiring and ribbon orientation are still unknown. The current bitstream leaves Pcam GPIO pins 11 and 12 unused. [Raspberry Pi's 15-pin camera pinout](https://www.raspberrypi.com/documentation/accessories/camera.html#camera-connector-pinout-15-pin) says pin 11 is typically an active-high power enable; [Digilent's Zybo Z7 manual](https://digilent.com/reference/_media/reference/programmable-logic/zybo-z7/zybo-z7_rm.pdf) confirms the Pcam connector exposes those GPIO signals. This is a possible cause of the missing acknowledgement, not a diagnosis. Do not drive either pin until the exact camera module circuit is identified from its markings or photos.

The owner supplied the [OV5647 sensor datasheet](https://cdn.sparkfun.com/datasheets/Dev/RaspberryPi/ov5647_full.pdf). Its SCCB address and chip-ID registers confirm that the probe targeted the right sensor address; its power-up sequence requires a running master clock and delays that have not been verified on this camera board. See [datasheet notes](ov5647_datasheet_notes.md). The transmit error therefore does not establish that the sensor itself is faulty.

## Next evidence needed

1. Connect Zybo HDMI OUT to an external HDMI monitor or a USB HDMI capture device and check for the grayscale bars. The laptop's built-in HDMI port cannot receive them.
2. Obtain clear photos of both sides of the camera PCB and the ribbon orientation at the Zybo Pcam socket.
3. Identify the exact module's power-enable and oscillator circuit, then add the appropriate GPIO/clock control to the FPGA design and retry the chip-ID read.
4. Only after a valid `0x5647` ID, initialize the sensor and VDMA S2MM capture path.
