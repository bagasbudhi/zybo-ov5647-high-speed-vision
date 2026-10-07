#include "zcam_protocol.h"
#include <string.h>

static void be16(uint8_t *p, uint16_t v) { p[0]=(uint8_t)(v>>8); p[1]=(uint8_t)v; }
static void be32(uint8_t *p, uint32_t v) {
    p[0]=(uint8_t)(v>>24); p[1]=(uint8_t)(v>>16);
    p[2]=(uint8_t)(v>>8); p[3]=(uint8_t)v;
}
static void be64(uint8_t *p, uint64_t v) {
    be32(p, (uint32_t)(v>>32)); be32(p+4, (uint32_t)v);
}
static uint32_t crc32_update(uint32_t crc, const uint8_t *p, size_t n) {
    size_t i;
    for (i=0; i<n; ++i) {
        unsigned bit;
        crc ^= p[i];
        for (bit=0; bit<8; ++bit)
            crc = (crc >> 1) ^ (0xEDB88320u & (0u - (crc & 1u)));
    }
    return crc;
}

int zcam_send_frame(const uint8_t *frame, uint16_t width, uint16_t height,
                    uint32_t frame_id, uint32_t *sequence,
                    uint64_t timestamp_ns, zcam_send_fn send, void *user) {
    uint8_t packet[ZCAM_MAX_DATAGRAM];
    size_t total, offset = 0;
    uint16_t index, count;
    if (!frame || !sequence || !send || !width || !height ||
        width > 4096 || height > 4096) return -1;
    total = (size_t)width * height;
    if (total > 4096u * 4096u) return -1;
    count = (uint16_t)((total + ZCAM_MAX_PAYLOAD - 1) / ZCAM_MAX_PAYLOAD);
    for (index=0; index<count; ++index) {
        size_t length = total - offset;
        uint32_t crc;
        if (length > ZCAM_MAX_PAYLOAD) length = ZCAM_MAX_PAYLOAD;
        packet[0]='Z'; packet[1]='C'; packet[2]='A'; packet[3]='M';
        packet[4]=1; packet[5]=1; be16(packet+6, 0);
        be32(packet+8, frame_id); be32(packet+12, *sequence);
        be16(packet+16, width); be16(packet+18, height);
        be16(packet+20, index); be16(packet+22, count);
        be64(packet+24, timestamp_ns);
        memcpy(packet+ZCAM_HEADER_BYTES, frame+offset, length);
        crc = crc32_update(0xFFFFFFFFu, packet, 32);
        crc = crc32_update(crc, packet+ZCAM_HEADER_BYTES, length) ^ 0xFFFFFFFFu;
        be32(packet+32, crc);
        if (send(packet, ZCAM_HEADER_BYTES+length, user) != 0) return -2;
        ++(*sequence);
        offset += length;
    }
    return count;
}
