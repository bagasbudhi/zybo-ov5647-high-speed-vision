# OV5647 datasheet checks for this board

Source: [OV5647 preliminary specification, version 1.0](https://cdn.sparkfun.com/datasheets/Dev/RaspberryPi/ov5647_full.pdf), supplied by the camera owner. This document describes the **sensor die** and a reference circuit. It does not identify the power regulators, oscillator, GPIO wiring, or ribbon orientation of this particular compatible camera PCB.

| Sensor fact | Datasheet location | Project consequence |
| --- | --- | --- |
| SCCB write/read IDs are `0x6C`/`0x6D`, equivalent to 7-bit address `0x36`. | Section 7, register tables | The first IIC probe used the intended sensor address. |
| Chip ID high/low at `0x300A`/`0x300B` is `0x56`/`0x47`. | Section 7, system control registers | A successful read should give `0x5647`. |
| Master clock input range is 6–27 MHz. | Key specifications | Identify the camera board oscillator or supplied XCLK before expecting SCCB access. |
| PWDN is active high; RESETB is active low. | Sections 2.5–2.7 | Do not infer the Pcam GPIO polarity from these die pins: the camera PCB may invert or gate them. |
| The master clock must run at least 1 ms before SCCB access; allow 20 ms after PWDN release or RESETB release for initialization. | Section 2.5 | The previous chip-ID attempt did not verify these preconditions, so its TX error does not prove a bad sensor. |
| Sensor supply domains differ from the connector's 3.3 V rail. | Key specifications and section 2.5 | Never apply Pcam 3.3 V directly to an unknown die pin. The camera PCB must provide the proper regulation and I/O translation. |

## Current hardware conclusion

The AXI IIC transaction to address `0x36` produced no chip-ID bytes and a transmit error. Since the current FPGA design leaves Pcam GPIO pins 11 and 12 unused and the exact camera PCB is unidentified, first verify the ribbon orientation, PCB markings, clock source, power-enable circuit and reset circuit. Only then change FPGA GPIO assignments or drive those pins. A photo of both PCB sides and the ribbon at the Zybo connector is needed to make that change safely.
