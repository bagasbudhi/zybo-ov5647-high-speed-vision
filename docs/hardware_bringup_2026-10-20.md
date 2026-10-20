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

Digilent's manual specifies that at the **Zybo Pcam socket**, the FFC contacts face the board's top edge, away from its center, and the off-white latch must be fully closed. Its Pcam table identifies pin 11 and pin 12 as GPIO, pins 13/14 as SCL/SDA with 1.5 kΩ pull-ups, and pin 15 as 3.3 V. The board connection alone does not establish the camera module's pin-11/12 circuitry. Check cable orientation with board power off before retrying I²C.

The owner supplied the [OV5647 sensor datasheet](https://cdn.sparkfun.com/datasheets/Dev/RaspberryPi/ov5647_full.pdf). Its SCCB address and chip-ID registers confirm that the probe targeted the right sensor address; its power-up sequence requires a running master clock and delays that have not been verified on this camera board. See [datasheet notes](ov5647_datasheet_notes.md). The transmit error therefore does not establish that the sensor itself is faulty.

## Next evidence needed

1. Connect Zybo HDMI OUT to an external HDMI monitor or a USB HDMI capture device and check for the grayscale bars. The laptop's built-in HDMI port cannot receive them.
2. Obtain clear photos of both sides of the camera PCB and the ribbon orientation at the Zybo Pcam socket.
3. Identify the exact module's power-enable and oscillator circuit, then add the appropriate GPIO/clock control to the FPGA design and retry the chip-ID read.
4. Only after a valid `0x5647` ID, initialize the sensor and VDMA S2MM capture path.

## Retest after the ribbon was inserted

A later photo on 20 October shows a ribbon entering J2 between HDMI RX and HDMI TX; the earlier photo showed J2 empty. The angle does not establish which side of the ribbon has exposed contacts or show the camera-end connector. The board had been power cycled, so JTAG initially reported that the FPGA bitstream was absent. The existing bitstream was reloaded into volatile configuration, PS DDR was initialized, and the HDMI grayscale frame/VDMA smoke setup again reported `0x00011000` for MM2S status (no transfer error).

The chip-ID probe was repeated with the ribbon visible in J2. AXI IIC began idle (`SR=0xC0`), then reported `ISR=0xD6`, TX FIFO occupancy 3, and RX FIFO occupancy 0. No `0x5647` ID was obtained. The IIC controller was reset to idle (`SR=0xC0`). This result is consistent with the previous attempt, but neither photo verifies camera-side ribbon orientation or the module power/clock circuit. Do not interpret the failed read as proof that the sensor is defective.

## Retest on 21 October 2026

Windows detected Zybo USB serial/JTAG and an active 1 Gbps Ethernet link. After a board power cycle, the FPGA bitstream was absent, so the same checked-in bitstream was loaded into volatile configuration. PS DDR initialization and the grayscale HDMI smoke setup completed; MM2S status was again `0x00011000` without transfer-error bits. HDMI video was not visually checked.

The read-only OV5647 chip-ID request to 7-bit address `0x36`, register `0x300A`, again returned no bytes. AXI IIC showed idle `SR=0xC0` before the request, then `ISR=0xD6`, TX occupancy 3, RX occupancy 0. AXI IIC was reset and returned to idle `SR=0xC0`. The repeated result does not distinguish cable contact orientation, camera-end connection, power enable, reset, and XCLK. No Pcam GPIO was driven.
