# Verification results, 7 October 2026

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
| Whole-system place/route | Passed | Routed WNS +0.843 ns; 7,544 LUTs, 12,058 registers, 9 BRAM tiles after route. This is a Vivado timing result; external I/O timing and camera signal integrity still need hardware validation. |
| Bitstream and handoff | Produced | `build/system/zybo_camera_system.bit` (2,083,866 bytes) and `build/system/zybo_camera_system.xsa` (hardware handoff without embedded bitstream). |
| DRC | 0 errors | 12 warnings: 3 LUT-equation notices, 8 RAMB36 async-control notices and 1 unroutable-load notice. Review before hardware signoff. |
| Live OV5647 to HDMI | Not done | Sensor identity, laptop HDMI input mode and board programming have not been tested. Vitis sensor/VDMA startup software is still needed. |

The final HDMI build log is `build/hdmi_final_build.log`. It uses the local Digilent IP copy in `fpga/ip_repo` and a pixel-clock-synchronized reset. The updated XSA contains the HDMI VTC and TX blocks; it does not embed the bitstream. The HDMI output uses 640 × 480 timing at a 25 MHz pixel clock, so the exact refresh rate is approximately 59.52 Hz. The image is grayscale until a color demosaic stage is added. The board and laptop HDMI input have not been physically tested.

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
