# Hardware inventory, 7 October 2026

| Item | Observed | Remaining check |
| --- | --- | --- |
| Target board | User reports Digilent Zybo Z7-10; Vivado target set to `xc7z010clg400-1`. | Read board revision from PCB. |
| Camera | Photos show Raspberry Pi Camera Rev 1.3, with an X1 oscillator component; OV5647 chip ID `0x5647` was read on board after Pcam pin 11 was enabled. | Verify CSI-2 streaming and frame capture. |
| Tool | `C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat`, Vivado 2025.2 build 6299465. Official Digilent Z7-10 board files were copied into `fpga/board_files` under their MIT license. | Verify physical board revision. |
| Processor tools | Vitis 2025.2 and `xsct.bat` exist; XSCT connected to both Cortex-A9 cores and programmed the board over JTAG. | Build a complete board application. |
| Camera receiver IP | `mipi_csi2_rx_subsystem:6.0`, two lanes, RAW10, nominal 292 Mb/s per lane generated and routed for XC7Z010; IP status says Included. | Test exact sensor lane rate and receiver lock on hardware. |
| Board link | Digilent manual: two CSI-2 lanes tested to 672 Mb/s each. | Verify mode and lock in hardware. |
| Laptop path | MSI Bravo 15 C7VFK. [MSI specifies HDMI-out](https://storage-asset.msi.com/excelSku/ca/nb/Bravo%2015%20C7VFK-057CA%20.pdf), so a direct cable from Zybo HDMI OUT cannot show video on its built-in port. Ethernet link is up at 1 Gbps. | Use an external HDMI monitor or USB capture device to view HDMI; build board Ethernet firmware for the Python viewer. |

The installed Vivado initially failed at Tcl Store user app installation. Launching with `XILINX_LOCAL_USER_DATA=NO` solved startup. A regular `launch_runs` child failed with `rundef.js ... Access denied` in this managed workspace, so the build uses in-process `synth_design` for block-level RTL. This environment behavior is separate from FPGA design validity.

The generated IP's `video_out` is a 16-bit AXI4-Stream sample with SOF/EOL sidebands. `axis_raw10_to_bayer8.sv` assumes valid RAW10 bits are `[9:0]` and discards two LSBs. Verify that assumption with a known OV5647 test pattern before using camera images. The receiver's generated port template is under `build/vivado/.../csi_rx_2lane_raw10.veo`.

`fpga/build_system.tcl` applies the Digilent Z7-10 PS preset and connects CSI-2 RX, custom RTL, stream width converter, VDMA write/read, I2C, DDR, video timing and HDMI TX. `fpga/ip_repo` contains the Digilent rgb2dvi IP and TMDS interface definition with its license. The board software and sensor bring-up are still required to make the camera-to-HDMI path useful.

`fpga/pcam_pins_reference.xdc` records Digilent's Pcam pin assignments. It is deliberately excluded from the current unconnected RTL synthesis project. Add its relevant lines only once the board-level top and D-PHY clocks are established.
