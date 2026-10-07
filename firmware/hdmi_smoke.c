/* Standalone Vitis application: repeat a known grayscale frame over HDMI.
 * Requires the Zynq PS/DDR initialized by the platform and this project's XSA.
 * Reserve ZCAM_FRAME_BASE..+307200 in the linker/memory map before running.
 * This does not configure or read the OV5647.
 */
#include <stdint.h>
/* Provided by the standalone Xilinx platform/BSP at link time. */
extern void Xil_DCacheFlushRange(uintptr_t address, uint32_t length);

#ifndef ZCAM_FRAME_BASE
#define ZCAM_FRAME_BASE 0x10000000u
#endif
#define VDMA_BASE 0x43000000u
#define VTC_BASE  0x43C10000u
#define WIDTH 640u
#define HEIGHT 480u

static void reg_write(uint32_t base, uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)(base + offset) = value;
}

static uint32_t reg_read(uint32_t base, uint32_t offset)
{
    return *(volatile uint32_t *)(uintptr_t)(base + offset);
}

int main(void)
{
    volatile uint8_t *frame = (volatile uint8_t *)(uintptr_t)ZCAM_FRAME_BASE;
    for (uint32_t y = 0; y < HEIGHT; ++y) {
        for (uint32_t x = 0; x < WIDTH; ++x) {
            uint32_t bar = x / 80u;
            frame[y * WIDTH + x] = (uint8_t)((bar * 32u) ^ ((y / 40u) & 1u ? 0x1fu : 0u));
        }
    }
    Xil_DCacheFlushRange((uintptr_t)ZCAM_FRAME_BASE, WIDTH * HEIGHT);

    /* VTC generator uses the 640x480 timing initialized in Vivado IP.
     * 0x01ffff07 selects generation registers and enables updates/generator.
     */
    reg_write(VTC_BASE, 0x00u, 0x01ffff07u);

    /* Circular MM2S playback of three identical frame addresses. The last
     * VSIZE write commits and starts the VDMA read channel. No S2MM startup.
     */
    reg_write(VDMA_BASE, 0x00u, 0x00000001u);
    reg_write(VDMA_BASE, 0x5cu, ZCAM_FRAME_BASE);
    reg_write(VDMA_BASE, 0x60u, ZCAM_FRAME_BASE);
    reg_write(VDMA_BASE, 0x64u, ZCAM_FRAME_BASE);
    reg_write(VDMA_BASE, 0x58u, WIDTH);
    reg_write(VDMA_BASE, 0x54u, WIDTH);
    reg_write(VDMA_BASE, 0x50u, HEIGHT);

    for (;;) {
        /* VDMASR bits 4-6 are internal/slave/decode error indicators. */
        if (reg_read(VDMA_BASE, 0x04u) & 0x70u) {
            return 1;
        }
    }
}
