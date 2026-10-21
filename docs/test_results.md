# Verification results through 21 October 2026

## Latest physical camera and Ethernet check (21 October 2026)

| Check | Result | Scope |
| --- | --- | --- |
| JTAG/ARM access | Recovered | After board restart, the current bitstream, PS/DDR setup, OV5647 configuration, and Ethernet sender were loaded and started. The prior ARM/DAP access fault was temporary. |
| OV5647 CSI-2 reception | Passed | The CSI packet counter advanced during live sensor output. |
| VDMA capture and HDMI read status | Running | Fresh S2MM and MM2S status read `0x00011000`; this register check alone does not prove a correct TV image. |
| Live Ethernet frame transport | Passed | A 10-second room-view run reconstructed 45 complete 640x480 Bayer8 frames from 9,901 packets, with zero dropped frames and zero bad packets. |
| Laptop YOLO inference | Functional, accuracy unverified | The second room-view run emitted 44 boxes over 45 frames. A `lamp 0.31` box is visually plausible; `table 0.65` and `chair 0.36` examples are ambiguous. See [annotated frames](live_ethernet_detection.md). |
| Live camera on TV and red-box overlay | Unverified | The owner reported a glitchy TV image; no current TV photo has been inspected. Do not claim a verified live HDMI image or threshold-192 overlay. |

The sections below retain historical build and bring-up results. Their earlier statements about JTAG or Ethernet availability are superseded by the physical check above.

## Earlier overlay build checks (21 October 2026)

| Check | Result | Scope |
| --- | --- | --- |
| Bayer/ROI/overlay XSim | Passed | All four CFA phases, AXI stalls, detection count and box, red outline on next frame, empty-frame clear. |
| Host unit tests | 7 passed | Bayer reference, UDP protocol, and tiny MLP synthetic detection. |
| Live sensor metrics (earlier threshold-32 run) | Passed | 7,351 completed frames; 67,427/76,800 bright ROI pixels; bbox covered the full ROI. |
| Threshold selection | 192 offline | A private optical frame yielded 552 hits and bbox x=296..380, y=180..286; this has not been confirmed on FPGA. |
| Vivado system route | Passed | WNS +0.599 ns, TNS 0, 0 failing endpoints; 8,400 LUTs, 13,402 registers, 9 BRAM tiles, 0 DSP. |
| DRC | Passed | 0 errors; report retained in `system_drc.txt`. |
| Artifacts | Built | Updated `artifacts/zybo_camera_system.bit` and matching XSA include the threshold-192 design. |
| TV color bars | Owner confirmed | Earlier HDMI TX run displayed color bars on the connected TV. |
| Standalone NN RTL | Passed simulation and synthesis | XSim passed; synthesis-only utilization is 424 LUTs, 298 registers, 0 DSP, 0 BRAM on XC7Z010. Not integrated into the camera system. |
| NN synthetic holdout | 997/1,000 correct | 497/500 centered targets and 500/500 negatives at score threshold 0.88; generated data only. |
| Physical-board check at that time | Incomplete | JTAG saw `xc7z010`, but the ARM/DAP target returned AHB AP transaction errors. That temporary access fault was resolved in the later check above; the threshold-192 overlay remains unverified on TV. |


## Earlier threshold-32 camera and HDMI checks (historical)

## Bayer RGB and ROI milestone update

The following results supersede earlier grayscale-only and “no HDMI path started” statements below for the current build:

| Check | Result | Scope |
| --- | --- | --- |
| Bayer demosaic + ROI detector XSim | Passed | Four CFA phases, constant RGB reconstruction in the interior, AXI sidebands, downstream stalls, bright-pixel count, bounding box, and malformed frame. |
| Host Bayer PNG/reference tests | 3 passed | Four CFA phase patterns, frame-size validation, and PNG output; all seven host tests pass including existing UDP protocol tests and the tiny MLP tests. |
| Current routed design | Passed | Vivado 2025.2 threshold-192 build; WNS +0.599 ns, no failing setup endpoints; 8,400 LUTs, 13,402 registers, 9 BRAM tiles. |
| Bitstream/XSA at earlier attempt | Produced, not installed during that attempt | Bitstream and regenerated XSA include demosaic, detector, red box and metrics GPIO. ARM/DAP initialization failed in that earlier session; later JTAG access recovered. |
| OV5647 color-bar frame | Captured | Sensor color-bar mode, CSI packet counter advanced, S2MM status `0x00011000`, 307,200-byte Bayer8 buffer read from DDR over JTAG, and rendered to [`ov5647_colorbars_demosaiced_640x480.png`](captures/ov5647_colorbars_demosaiced_640x480.png) with the host reference. |
| HDMI test pattern | Earlier smoke output photographed by owner | The photo in `captures/zybo_hdmi_tv_colorbars_user_photo.jpeg` shows HDMI test bars on the TV; it does not prove the new overlay or live camera video. |
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
| Whole-system place/route | Passed | Threshold-192 Bayer/ROI/overlay build routed WNS +0.599 ns; 8,400 LUTs, 13,402 registers, 9 BRAM tiles after route. This is a Vivado timing result; external I/O timing and camera signal integrity still need hardware validation. |
| Bitstream and handoff | Produced | `build/system/zybo_camera_system.bit` (2,083,866 bytes) and `build/system/zybo_camera_system.xsa` (hardware handoff without embedded bitstream). |
| DRC | 0 errors | 12 warnings: 3 LUT-equation notices, 8 RAMB36 async-control notices and 1 unroutable-load notice. Review before hardware signoff. |
| Physical FPGA/DDR/VDMA smoke | Passed register checks | JTAG programmed the FPGA, initialized DDR, downloaded grayscale bars, and started VTC/VDMA MM2S. VDMA status had no transfer error. A photo confirms the earlier HDMI smoke pattern on a TV; live camera-to-TV and the new overlay remain unverified. |
| OV5647 chip-ID read | **Passed on physical board** | After routing Pcam pin 11/G20 to AXI GPIO and enabling it, AXI IIC at 7-bit address `0x36` returned `0x56`, `0x47` from `0x300A`/`0x300B`. Earlier attempts without the enable returned no bytes. See the [21 October log](hardware_bringup_2026-10-21.md). |
| Live OV5647 CSI-2 reception | **Passed on physical board** | VGA RAW10 packets and frame-end events observed. VC0 data type was `0x2B`; line payload was 800 bytes. After clearing prior flags, no fresh CSI error bits appeared in the observation window. |
| OV5647 test-pattern DDR capture | **Passed on physical board** | VDMA S2MM wrote three 640×480 buffers. After clearing startup flags, S2MM status was `0x00011000`, with no error bits. One 307,200-byte frame was dumped by JTAG and visually inspected as a PNG. |
| OV5647 optical DDR capture | **Passed, dim scene** | With manual 500-line exposure and gain 32, a local 640×480 JTAG dump showed recognizable room geometry and 30 distinct Bayer8 values (range 2–41). Image is not published. |
| Earlier live OV5647 to HDMI | Partial at that time | OV5647 → DDR and DDR → HDMI streams ran with clean fresh VDMA status; live detector GPIO values were read over JTAG. The TV panel was not observed during that milestone. The later Ethernet run is reported at the top of this page; HDMI image quality and robust buffer ownership remain open. |

The routed HDMI design uses the local Digilent IP copy in `fpga/ip_repo` and a pixel-clock-synchronized reset. The updated XSA contains the HDMI VTC/TX and detector metrics GPIO; it does not embed the bitstream. The HDMI output uses 640 × 480 timing at a 25 MHz pixel clock (about 59.52 Hz). The Bayer color-bar PNG is reconstructed on the host from the frame dumped from Zybo DDR; the separate TV photo shows an HDMI smoke pattern, not the camera frame.

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

## Neural network experiment

- Host MLP: deterministic synthetic holdout set, 500 centered-target and 500 negative patches; at score threshold 0.88 it accepted 497/500 positives and 0/500 negatives.
- Sliding-window test: detected a synthetic 16x16 target in an 80x64 grayscale frame; the 24x24 proposal box IoU was 0.444 with the generated target.
- Standalone SystemVerilog MLP: XSim passed centered target, off-center negative, and output backpressure checks. It classifies one 4x4 pooled patch in 136 clocks.
- The MLP is not integrated into the CSI/VDMA/HDMI design. No real-camera object detection accuracy, throughput, FPGA resource use, or automotive performance is claimed.

Standalone MLP utilization is synthesis-only (`tiny_nn_synthesis_utilization.txt`); no routed timing, power estimate, or full-system integration result is claimed for it.
