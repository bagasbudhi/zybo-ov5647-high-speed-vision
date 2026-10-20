# Verification results through 21 October 2026

| Check | Result | Scope |
| --- | --- | --- |
| Python `unittest discover` | 2 passed | UDP reassembly with reverse packet order, CRC rejection and timeout. |
| Python video window | Not run | `numpy` and `opencv-python` are not installed in the current Python environment; `host/requirements.txt` lists them. The protocol and synthetic sender compile. |
| Cortex-A9 UDP packetizer | Cross-compiled | `firmware/zcam_protocol.c` compiled with Vitis `arm-none-eabi-gcc -Wall -Wextra -Werror`; no Vitis application or on-board UDP send has been built. |
| HDMI smoke test C | Cross-compiled | `firmware/hdmi_smoke.c` compiled for Cortex-A9 with `-Wall -Wextra -Werror`; it still needs a Vitis standalone BSP, ELF link and hardware run. |
| Vivado `xvlog/xelab/xsim` | 2 testbenches passed | Frame completion, edge metric, short line, truncated frame, 3 stalled cycles, pass-through data and sidebands; pipeline RAW10 sample conversion. |
| CSI-2 RX IP generation | Passed | Vivado 2025.2 produced two-lane RAW10, nominal 292 Mb/s/lane IP for XC7Z010; catalog reports Included license. The integrated receiver was routed, but the live link is untested. |
| Custom RTL `synth_design` | Passed | Pipeline top: 51 LUTs, 188 registers, 0 BRAM, 0 DSP. In-process block synthesis only. |
| Custom RTL timing summary | WNS +2.763 ns at 100 MHz | Synthesis estimate for the isolated pipeline, not placed-and-routed board timing. |
| Digilent board-preset block design | Validated | PS7 DDR/ENET0, AXI IIC, two-lane CSI RX, custom RTL, VDMA S2MM/MM2S, PS HP0, VGA VTC, AXI video out and Digilent HDMI TX. |
| Whole-system synthesis | Passed | Final HDMI-enabled design synthesized with no synthesis errors. |
| Whole-system place/route | Passed | Camera-power-enabled build routed WNS +0.376 ns; 7,605 LUTs, 12,095 registers, 9 BRAM tiles after route. This is a Vivado timing result; external I/O timing and camera signal integrity still need hardware validation. |
| Bitstream and handoff | Produced | `build/system/zybo_camera_system.bit` (2,083,866 bytes) and `build/system/zybo_camera_system.xsa` (hardware handoff without embedded bitstream). |
| DRC | 0 errors | 12 warnings: 3 LUT-equation notices, 8 RAMB36 async-control notices and 1 unroutable-load notice. Review before hardware signoff. |
| Physical FPGA/DDR/VDMA smoke | Passed register checks | JTAG programmed the FPGA, initialized DDR, downloaded grayscale bars, and started VTC/VDMA MM2S. VDMA status had no transfer error. No display/capture observation yet. |
| OV5647 chip-ID read | **Passed on physical board** | After routing Pcam pin 11/G20 to AXI GPIO and enabling it, AXI IIC at 7-bit address `0x36` returned `0x56`, `0x47` from `0x300A`/`0x300B`. Earlier attempts without the enable returned no bytes. See the [21 October log](hardware_bringup_2026-10-21.md). |
| Live OV5647 to HDMI/Ethernet | Not done | Sensor mode setup, CSI status verification, and VDMA capture firmware are still needed. HDMI validation needs an external monitor or USB capture device; Ethernet streaming firmware is not yet implemented. |

The final HDMI build log is `build/hdmi_final_build.log`. It uses the local Digilent IP copy in `fpga/ip_repo` and a pixel-clock-synchronized reset. The updated XSA contains the HDMI VTC and TX blocks; it does not embed the bitstream. The HDMI output uses 640 × 480 timing at a 25 MHz pixel clock, so the exact refresh rate is approximately 59.52 Hz. The image is grayscale until a color demosaic stage is added. The FPGA/DDR/VDMA path was checked on board; HDMI output has not been observed on a display or capture device.

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
