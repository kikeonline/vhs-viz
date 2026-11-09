#include "VHSRealtime.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2 && ATOMIC_INT_LOCK_FREE == 2, "Lock-free atomics required");
struct VHSBridge {
    atomic_uint refs, read, write, dropped;
    _Atomic(uint64_t) values[4];
    VHSInput slots[256];
    void* context;
    VHSEdit edit;
};
VHSBridge* vhs_bridge_create(void) {
    VHSBridge* b = calloc(1, sizeof(*b));
    if (!b) return NULL;
    atomic_init(&b->refs, 1); atomic_init(&b->read, 0);
    atomic_init(&b->write, 0); atomic_init(&b->dropped, 0);
    for (unsigned i=0; i<4; ++i) atomic_init(&b->values[i], 0);
    vhs_bridge_set(b, 0, .24); vhs_bridge_set(b, 1, .08); vhs_bridge_set(b, 2, .62);
    return b;
}
void vhs_bridge_retain(VHSBridge* b) { atomic_fetch_add_explicit(&b->refs, 1, memory_order_relaxed); }
void vhs_bridge_release(VHSBridge* b) {
    if (atomic_fetch_sub_explicit(&b->refs, 1, memory_order_acq_rel) == 1) free(b);
}
int vhs_bridge_push(VHSBridge* b, VHSInput input) {
    unsigned w = atomic_load_explicit(&b->write, memory_order_relaxed);
    unsigned r = atomic_load_explicit(&b->read, memory_order_acquire);
    if (w-r >= 256) { atomic_fetch_add_explicit(&b->dropped, 1, memory_order_relaxed); return 0; }
    b->slots[w % 256] = input;
    atomic_store_explicit(&b->write, w+1, memory_order_release); return 1;
}
int vhs_bridge_pop(VHSBridge* b, VHSInput* input) {
    unsigned r = atomic_load_explicit(&b->read, memory_order_relaxed);
    if (r == atomic_load_explicit(&b->write, memory_order_acquire)) return 0;
    *input = b->slots[r % 256];
    atomic_store_explicit(&b->read, r+1, memory_order_release); return 1;
}
uint32_t vhs_bridge_dropped(VHSBridge* b) { return atomic_load_explicit(&b->dropped, memory_order_acquire); }
void vhs_bridge_set(VHSBridge* b, uint32_t id, double value) {
    if (id >= 4 || !isfinite(value) || value < 0 || value > 1) return;
    uint64_t bits; memcpy(&bits, &value, sizeof(bits));
    atomic_store_explicit(&b->values[id], bits, memory_order_release);
}
double vhs_bridge_get(VHSBridge* b, uint32_t id) {
    if (id >= 4) return 0;
    uint64_t bits = atomic_load_explicit(&b->values[id], memory_order_acquire);
    double value; memcpy(&value, &bits, sizeof(value)); return value;
}
void vhs_bridge_callback(VHSBridge* b, void* context, VHSEdit edit) { b->context=context; b->edit=edit; }
void vhs_bridge_edit(VHSBridge* b, uint32_t id, double value, uint32_t phase) {
    if (b->edit) b->edit(b->context, id, value, phase);
}
