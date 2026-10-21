# Bayer RGB and ROI detector milestone

## Stream integration

The hardware path stores one byte per pixel in DDR. Bayer demosaicing is placed after AXI VDMA MM2S and before the existing AXI4-Stream Video Out/VTC and Digilent HDMI TX. This leaves the proven CSI-2, RAW10 unpacking, DDR write, and VDMA frame format in place. The new RTL accepts one Bayer8 pixel per beat and passes SOF (`TUSER`) and EOL (`TLAST`) unchanged while honoring downstream backpressure.

`BAYER_PHASE=0` is BGGR (top-left is blue). Other supported values are `1=GBRG`, `2=GRBG`, and `3=RGGB`. The default matches the OV5647 VGA mode orientation configured by this project. Confirm phase with a known color target if the sensor orientation or register setup changes.

The interpolator uses current, left, upper, and upper-left samples. At each pixel it averages the available values for each CFA color. It has no future-pixel lookahead, adds no stream latency, and uses one 8-bit line buffer. At the first row/column, missing color estimates fall back to the current Bayer sample. This is a low-resource causal approximation, not a conventional centered bilinear kernel; color edges can show directional bias.

## Detection metric

The detector receives RGB888 and overlays a two-pixel red outline from the previous completed frame while forwarding all other pixels. It computes the integer luma approximation. The synthesized system build overrides the RTL default threshold with 192:

```text
Y = (R + 2*G + B) >> 2
hit = (x=160..479) AND (y=120..359) AND (Y >= 192)
```

At a complete 640×480 frame end, it latches the number of hit pixels and the smallest axis-aligned bounding box around them. If no pixel hits, `detected_last=0` and the reported count is zero. The testbench verifies two hit pixels, the box coordinates, a bright pixel outside the ROI, malformed one-line input, stream pass-through, and backpressure.

## AXI GPIO registers

The design exposes detector state through two dual-channel AXI GPIO blocks. Each channel is input-only from the processor's perspective. Register offsets follow AXI GPIO: channel 1 data `+0x0`, channel 2 data `+0x8`.

| Address | Value |
| --- | --- |
| `0x41210000` | `bright_count_last` (32-bit count from most recently completed frame) |
| `0x41210008` | `bbox_x_pair`: bit 20 detected; bits 9:0 x minimum; bits 19:10 x maximum |
| `0x41220000` | `bbox_y_pair`: bits 8:0 y minimum; bits 17:9 y maximum |
| `0x41220008` | `frame_count` (completed valid frames since reset) |

`malformed_count` is retained in RTL but is not currently mapped to a processor-readable register. `fpga/read_vision_metrics_jtag.tcl` reads these locations. On the programmed FPGA, JTAG returned `frame_count=4991`, `bright_count_last=76800`, `detected=1`, and box `(160,120)` to `(479,359)` during sensor color-bar streaming. The ROI contains exactly 320×240=76,800 pixels, so this test pattern exceeded the luma threshold throughout the ROI. This demonstrates the live metric path; it does not establish a useful detection threshold for natural scenes.

## Image evidence

[`captures/ov5647_colorbars_demosaiced_640x480.png`](captures/ov5647_colorbars_demosaiced_640x480.png) is generated from a Bayer8 frame dumped over JTAG from the Zybo's DDR while the OV5647 color-bar test pattern was enabled. The host script `host/bayer8_to_rgb.py` uses the same interpolation policy as the RTL and defaults to BGGR. The generated image is useful to verify frame dimensions and color reconstruction from the received sensor frame. It is not a screenshot of the TV output. The owner's photo [`zybo_hdmi_tv_colorbars_user_photo.jpeg`](captures/zybo_hdmi_tv_colorbars_user_photo.jpeg) separately shows an HDMI test pattern on a TV from the earlier smoke build; it does not establish live camera-to-TV video. The newer threshold-192 overlay build has not yet been visually verified on hardware.

Recreate it from a new board capture:

```powershell
python host\bayer8_to_rgb.py build\capture\ov5647_colorbars_640x480.raw docs\captures\frame.png --phase BG
```

## Validation summary

- Vivado 2025.2 full Z7-10 implementation completed; routed WNS is +0.599 ns with no failing timing endpoints.
- Routed utilization: 8,400 LUTs (47.73%), 13,402 registers (38.07%), 9 BRAM tiles (15%), 0 DSPs.
- DRC: zero errors, 12 warnings and 2 advisories; see `system_drc.txt`.
- Bayer/ROI XSim testbench passed all four CFA phases, backpressure, counter, box, and malformed-frame checks.
- Host tests: 5 passed.
- JTAG hardware run: camera/CSI packet counter advanced, S2MM and MM2S fresh status both read `0x00011000`, the 307,200-byte Bayer8 frame was dumped from DDR, detector GPIO readback reported 76,800 ROI hits and the full ROI bounding box, and HDMI playback was started. The display panel itself was not visually verified during this run.

## Updated overlay and threshold build (21 October 2026)

`fpga/build_system.tcl` configures `LUMA_THRESHOLD=192`. Applying the matching causal Bayer-to-RGB host reference to a private natural-light capture yielded 552 hits in the ROI and box x=296..380, y=180..286. This is a threshold demonstration on one scene; threshold hits vary with exposure and lighting. The local scene image is deliberately excluded from the public repository.

`sim/tb_axis_bayer_vision.sv` checks that the red border matches the prior frame's box and that an empty frame clears the detector. XSim passes. The owner supplied a photo of the earlier HDMI test pattern on a TV. The threshold-192 bitstream/XSA are built, but the latest physical-board update could not be completed because the JTAG-visible ARM/DAP target did not respond; see `docs/test_results.md`.
