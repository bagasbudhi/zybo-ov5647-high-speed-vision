# Verification results through 21 October 2026

## Bayer RGB and ROI milestone update

The following results supersede earlier grayscale-only and “no HDMI path started” statements below for the current build:

| Check | Result | Scope |
| --- | --- | --- |
| Bayer demosaic + ROI detector XSim | Passed | Four CFA phases, constant RGB reconstruction in the interior, AXI sidebands, downstream stalls, bright-pixel count, bounding box, and malformed frame. |
| Host Bayer PNG/reference tests | 3 passed | Four CFA phase patterns, frame-size validation, and PNG output; all five host tests pass including existing UDP protocol tests. |
| Current routed design | Passed | Vivado 2025.2; WNS +0.590 ns, no failing timing endpoints; 8,310 LUTs, 13,402 registers, 9 BRAM tiles. |
| Current bitstream/XSA | Produced and installed | Bitstream and regenerated XSA include demosaic, detector, and metrics GPIO. |
| OV5647 color-bar frame | Captured | Sensor color-bar mode, CSI packet counter advanced, S2MM status `0x00011000`, 307,200-byte Bayer8 buffer read from DDR over JTAG, and rendered to [`ov5647_colorbars_demosaiced_640x480.png`](captures/ov5647_colorbars_demosaiced_640x480.png) with the host reference. |
| HDMI playback | Started, screen not observed | MM2S status `0x00011000`; output was started through the Zybo HDMI TX path. No TV/capture screenshot was available in this run. |
| Detector GPIO readback | Passed | JTAG reported frame count 4,991, 76,800 ROI hits, detection asserted, and box x=160…479, y=120…359 on the color-bar pattern. |

| Check | Result | Scope |
| --- | --- | --- |
| Python `unittest discover` | 2 passed | UDP reassembly with reverse packet order, CRC rejection and timeout. |
| Python video window | Not run | `numpy` and `opencv-python` are not installed in the current Python environment; `host/requirements.txt` lists them. The protocol and synthetic sender compile. |
| Cortex-A9 UDP packetizer | Cross-compiled | `firmware/zcam_protocol.c` compiled with Vitis `arm-none-eabi-gcc -Wall -Wextra -Werror`; no Vitis application or on-board UDP send has been built. |
| HDMI smoke test C | Cross-compiled | `firmware/hdmi_smoke.c` compiled for Cortex-A9 with `-Wall -Wextra -Werror`; it still needs a Vitis standalone BSP, ELF link and hardware run. |
| Vivado `xvlog/xelab/xsim` | 3 testbenches passed across the project | Existing frame monitor, raw pipeline, and new Bayer/ROI tests. |
| CSI-2 RX IP generation | Passed | Vivado 2025.2 produced two-lane RAW10, nominal 292 Mb/s/lane IP for XC7Z010; catalog reports Included license. The integrated receiver was routed and live RAW10 packets were observed on hardware. |
| Custom RTL `synth_design` | Passed | Pipeline top: 51 LUTs, 188 registers, 0 BRAM, 0 DSP. In-process block synthesis only. |
| Custom RTL timing summary | WNS +2.763 ns at 100 MHz | Synthesis estimate for the isolated pipeline, not placed-and-routed board timing. |
| Digilent board-preset block design | Validated | PS7 DDR/ENET0, AXI IIC, two-lane CSI RX, custom RTL, VDMA S2MM/MM2S, PS HP0, VGA VTC, AXI video out and Digilent HDMI TX. |
| Whole-system synthesis | Passed | Final HDMI-enabled design synthesized with no synthesis errors. |
| Whole-system place/route | Passed | Bayer/ROI-enabled build routed WNS +0.590 ns; 8,310 LUTs, 13,402 registers, 9 BRAM tiles after route. This is a Vivado timing result; external I/O timing and camera signal integrity still need hardware validation. |
| Bitstream and handoff | Produced | `build/system/zybo_camera_system.bit` (2,083,866 bytes) and `build/system/zybo_camera_system.xsa` (hardware handoff without embedded bitstream). |
| DRC | 0 errors | 12 warnings: 3 LUT-equation notices, 8 RAMB36 async-control notices and 1 unroutable-load notice. Review before hardware signoff. |
| Physical FPGA/DDR/VDMA smoke | Passed register checks | JTAG programmed the FPGA, initialized DDR, downloaded grayscale bars, and started VTC/VDMA MM2S. VDMA status had no transfer error. No display/capture observation yet. |
| OV5647 chip-ID read | **Passed on physical board** | After routing Pcam pin 11/G20 to AXI GPIO and enabling it, AXI IIC at 7-bit address `0x36` returned `0x56`, `0x47` from `0x300A`/`0x300B`. Earlier attempts without the enable returned no bytes. See the [21 October log](hardware_bringup_2026-10-21.md). |
| Live OV5647 CSI-2 reception | **Passed on physical board** | VGA RAW10 packets and frame-end events observed. VC0 data type was `0x2B`; line payload was 800 bytes. After clearing prior flags, no fresh CSI error bits appeared in the observation window. |
| OV5647 test-pattern DDR capture | **Passed on physical board** | VDMA S2MM wrote three 640×480 buffers. After clearing startup flags, S2MM status was `0x00011000`, with no error bits. One 307,200-byte frame was dumped by JTAG and visually inspected as a PNG. |
| OV5647 optical DDR capture | **Passed, dim scene** | With manual 500-line exposure and gain 32, a local 640×480 JTAG dump showed recognizable room geometry and 30 distinct Bayer8 values (range 2–41). Image is not published. |
| Live OV5647 to HDMI/Ethernet | Partial | OV5647 → DDR and DDR → HDMI streams both ran with clean fresh VDMA status; live detector GPIO values were read over JTAG. The TV panel was not observed during this milestone. Sustained FPS, robust buffer ownership, and Ethernet streaming firmware remain. |

The routed HDMI design uses the local Digilent IP copy in `fpga/ip_repo` and a pixel-clock-synchronized reset. The updated XSA contains the HDMI VTC/TX and detector metrics GPIO; it does not embed the bitstream. The HDMI output uses 640 × 480 timing at a 25 MHz pixel clock (about 59.52 Hz). The Bayer color-bar PNG is reconstructed on the host from the frame dumped from Zybo DDR; it is not a screenshot of HDMI output.

The isolated custom RTL synthesis log contains five critical warnings about CSI IP constraint modules not found because the generated receiver IP is **not instantiated** in that isolated top. The whole-system build uses the receiver. The Digilent PS preset also emits negative DDR DQS skew warnings. Neither report establishes memory behavior on the physical board; test DDR before trusting captured frames.

## Reproduce completed checks

From the project directory in PowerShell:

```powershell
python -m unittest discover -s host -p 'test_*.py' -v
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xvlog.bat' -sv 'rtl\axis_frame_monitor.sv' 'sim\tb_axis_frame_monitor.sv'
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xelab.bat' tb_axis_frame_monitor -s tb_axis_frame_monitor
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xsim.bat' tb_axis_frame_monitor -runall
$env:XILINX_LOCAL_USER_DATA='NO'
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' -mode batch -nojournal -nolog -source 'fpga\build.tcl'
```

To view synthetic video, install `host/requirements.txt`, run `python host/viewer.py` in one terminal, then `python host/demo_sender.py` in another. This checks the laptop path only; it does not read the camera.
