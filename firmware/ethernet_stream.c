#include <stdint.h>
#include <string.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_exception.h"
#include "xil_printf.h"
#include "xscugic.h"
#include "sleep.h"
#include "netif/xadapter.h"
#include "lwip/init.h"
#include "lwip/ip4_addr.h"
#include "lwip/pbuf.h"
#include "lwip/udp.h"
#include "zcam_protocol.h"

#define VDMA 0x43000000u
#define FRAME0 0x11000000u
#define FRAME_STRIDE 0x00080000u

static struct netif ethernet;
static struct udp_pcb *sender;
static ip_addr_t destination;
static uint8_t snapshot[ZCAM_FRAME_BYTES] __attribute__((aligned(64)));
static uint32_t sequence;

void _init(void) {}
void _fini(void) {}

static void phy_write(unsigned reg, unsigned value)
{
    Xil_Out32(XPAR_XEMACPS_0_BASEADDR + 0x34u,
              0x50020000u | (1u << 23) | (reg << 18) | value);
    while (!(Xil_In32(XPAR_XEMACPS_0_BASEADDR + 0x08u) & 4u)) {}
}

static unsigned phy_read(unsigned reg)
{
    Xil_Out32(XPAR_XEMACPS_0_BASEADDR + 0x34u,
              0x60020000u | (1u << 23) | (reg << 18));
    while (!(Xil_In32(XPAR_XEMACPS_0_BASEADDR + 0x08u) & 4u)) {}
    return Xil_In32(XPAR_XEMACPS_0_BASEADDR + 0x34u) & 0xffffu;
}

static void configure_rgmii_delay(void)
{
    unsigned old_page = phy_read(31);
    unsigned delay;
    phy_write(31, 7);
    phy_write(30, 0xa4);
    delay = phy_read(28);
    phy_write(28, delay | 0x3800u);
    xil_printf("PHY_RGMII_DELAY=%04x->%04x\r\n", delay, phy_read(28));
    phy_write(31, old_page);
}

static int send_datagram(const uint8_t *data, size_t size, void *unused)
{
    struct pbuf *p;
    err_t err;
    (void)unused;
    p = pbuf_alloc(PBUF_TRANSPORT, (u16_t)size, PBUF_RAM);
    if (!p) return -1;
    if (pbuf_take(p, data, (u16_t)size) != ERR_OK) {
        pbuf_free(p);
        return -1;
    }
    err = udp_sendto(sender, p, &destination, 5005);
    pbuf_free(p);
    return err == ERR_OK ? 0 : -1;
}

static void start_capture(void)
{
    Xil_Out32(VDMA + 0x30, 4);
    usleep(1000);
    Xil_Out32(VDMA + 0x30, 3);
    Xil_Out32(VDMA + 0xAC, FRAME0);
    Xil_Out32(VDMA + 0xB0, FRAME0 + FRAME_STRIDE);
    Xil_Out32(VDMA + 0xB4, FRAME0 + 2 * FRAME_STRIDE);
    Xil_Out32(VDMA + 0xA8, ZCAM_WIDTH);
    Xil_Out32(VDMA + 0xA4, ZCAM_WIDTH);
    Xil_Out32(VDMA + 0xA0, ZCAM_HEIGHT);
    xil_printf("VDMA_S2MM_STATUS=%08x\r\n", Xil_In32(VDMA + 0x34));
}

int main(void)
{
    unsigned char mac[6] = {0x02, 0x5a, 0x79, 0x42, 0x4f, 0x10};
    ip4_addr_t address, mask, gateway, host;
    uint32_t frame_id = 0;
    uint32_t last_write = 0xffffffffu;
    unsigned idle = 0;
    int sent;

    xil_printf("ZCAM Ethernet stream boot\r\n");
    Xil_ExceptionInit();
    XScuGic_DeviceInitialize(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
        (Xil_ExceptionHandler)XScuGic_DeviceInterruptHandler,
        (void *)XPAR_SCUGIC_SINGLE_DEVICE_ID);
    lwip_init();
    IP4_ADDR(&address, 169, 254, 80, 26);
    IP4_ADDR(&mask, 255, 255, 0, 0);
    IP4_ADDR(&gateway, 0, 0, 0, 0);
    IP4_ADDR(&host, 169, 254, 255, 255);
    if (!xemac_add(&ethernet, &address, &mask, &gateway, mac,
                   XPAR_XEMACPS_0_BASEADDR)) {
        xil_printf("Ethernet interface failed\r\n");
        return 1;
    }
    netif_set_default(&ethernet);
    netif_set_up(&ethernet);
    Xil_ExceptionEnableMask(XIL_EXCEPTION_IRQ);
    configure_rgmii_delay();
    sender = udp_new();
    if (!sender) return 2;
    sender->so_options |= SOF_BROADCAST;
    ip_addr_copy_from_ip4(destination, host);
    start_capture();
    xil_printf("Board 169.254.80.26 -> 169.254.255.255 broadcast UDP:5005\r\n");

    for (;;) {
        uint32_t writing, completed;
        xemacif_input(&ethernet);
        writing = (Xil_In32(VDMA + 0x28) >> 24) & 0x1fu;
        if (writing > 2 || writing == last_write) {
            if (++idle == 1000000u) {
                xil_printf("WAIT frame=%u status=%08x park=%08x link=%u\r\n",
                    frame_id, Xil_In32(VDMA + 0x34),
                    Xil_In32(VDMA + 0x28), netif_is_link_up(&ethernet));
                idle = 0;
            }
            continue;
        }
        idle = 0;
        last_write = writing;
        completed = (writing + 2u) % 3u;
        Xil_DCacheInvalidateRange(FRAME0 + completed * FRAME_STRIDE,
                                  ZCAM_FRAME_BYTES);
        memcpy(snapshot, (const void *)(uintptr_t)(FRAME0 + completed * FRAME_STRIDE),
               ZCAM_FRAME_BYTES);
        if (((Xil_In32(VDMA + 0x28) >> 24) & 0x1fu) == completed) continue;
        sent = zcam_send_frame(snapshot, ZCAM_WIDTH, ZCAM_HEIGHT,
                               frame_id++, &sequence, 0, send_datagram, 0);
        xil_printf("FRAME=%u chunks=%d status=%08x\r\n", frame_id, sent,
                   Xil_In32(VDMA + 0x34));
        xemacif_input(&ethernet);
        usleep(200000);
    }
}
