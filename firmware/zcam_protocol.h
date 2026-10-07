#ifndef ZCAM_PROTOCOL_H
#define ZCAM_PROTOCOL_H

#include <stddef.h>
#include <stdint.h>

#define ZCAM_WIDTH 640u
#define ZCAM_HEIGHT 480u
#define ZCAM_FRAME_BYTES (ZCAM_WIDTH * ZCAM_HEIGHT)
#define ZCAM_MAX_PAYLOAD 1400u
#define ZCAM_HEADER_BYTES 36u
#define ZCAM_MAX_DATAGRAM (ZCAM_HEADER_BYTES + ZCAM_MAX_PAYLOAD)

/* Callback returns zero on success. Supply a UDP sendto adapter in the
 * Vitis/lwIP application. No allocation is performed in this library. */
typedef int (*zcam_send_fn)(const uint8_t *datagram, size_t length, void *user);

/* Returns number of datagrams sent or a negative error code. sequence is
 * incremented for every successfully sent datagram. */
int zcam_send_frame(const uint8_t *frame, uint16_t width, uint16_t height,
                    uint32_t frame_id, uint32_t *sequence,
                    uint64_t timestamp_ns, zcam_send_fn send, void *user);

#endif
