#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct VHSBridge VHSBridge;
// One producer (host process), one consumer (display timer). All memory preallocated.
typedef struct VHSInput {
    uint32_t kind; // 0 block/transport, 1 note on, 2 note off, 3 CC, 4 reset
    int32_t offset, channel, number;
    double value, tempo;
    int64_t sampleTime;
    uint32_t flags; // bit 0 context present, bit 1 playing, bit 2 tempo valid
} VHSInput;
VHSBridge* vhs_bridge_create(void);
void vhs_bridge_retain(VHSBridge*);
void vhs_bridge_release(VHSBridge*);
int vhs_bridge_push(VHSBridge*, VHSInput);
int vhs_bridge_pop(VHSBridge*, VHSInput*);
uint32_t vhs_bridge_dropped(VHSBridge*);
void vhs_bridge_set(VHSBridge*, uint32_t, double);
double vhs_bridge_get(VHSBridge*, uint32_t);
// Control-thread only. No Swift callback is ever installed on the audio path.
typedef void (*VHSEdit)(void*, uint32_t, double, uint32_t);
void vhs_bridge_callback(VHSBridge*, void*, VHSEdit);
void vhs_bridge_edit(VHSBridge*, uint32_t, double, uint32_t);
#ifdef __cplusplus
}
#endif

// Bounded document mailbox for host state/control operations, never process().
// Calls try once and return -1 on contention/capacity failure; no spinning.
#ifdef __cplusplus
extern "C" {
#endif
#define VHS_STATE_CAPACITY 131072
int vhs_bridge_store_document(VHSBridge*, const uint8_t*, uint32_t, uint32_t restored);
int vhs_bridge_copy_document(VHSBridge*, uint8_t*, uint32_t, uint32_t* restored, uint32_t* revision);
uint32_t vhs_bridge_document_revision(VHSBridge*);
#ifdef __cplusplus
}
#endif
#ifdef __cplusplus
extern "C" {
#endif
// UI publication cannot overwrite a host restore it has not consumed.
int vhs_bridge_publish_document(VHSBridge*, const uint8_t*, uint32_t, uint32_t expectedRevision, uint32_t* publishedRevision);
#ifdef __cplusplus
}
#endif
