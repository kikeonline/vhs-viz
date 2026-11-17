#include "VHSRealtime.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2 && ATOMIC_INT_LOCK_FREE == 2, "Lock-free atomics required");
struct VHSBridge {
    atomic_uint refs, read, write, dropped;
    _Atomic(uint64_t) values[4], automation[VHS_AUTOMATION_SLOTS];
    VHSAudioQueue* audio;
    atomic_uint hostSequence, bypass;
    _Atomic(uint64_t) host[5];
    VHSInput slots[256];
    atomic_flag documentBusy;
    atomic_uint documentRevision;
    uint32_t documentCount, documentRestored;
    uint8_t document[VHS_STATE_CAPACITY];
    void* context;
    VHSEdit edit;
};
VHSBridge* vhs_bridge_create(void) {
    VHSBridge* b = calloc(1, sizeof(*b));
    if (!b) return NULL;
    b->audio = vhs_audio_queue_create();
    if (!b->audio) { free(b); return NULL; }
    atomic_init(&b->hostSequence,0); atomic_init(&b->bypass,0);
    for (unsigned i=0;i<5;++i) atomic_init(&b->host[i],0);
    for (unsigned i=0;i<VHS_AUTOMATION_SLOTS;++i) atomic_init(&b->automation[i],0);
    atomic_init(&b->refs, 1); atomic_init(&b->read, 0);
    atomic_init(&b->write, 0); atomic_init(&b->dropped, 0);
    atomic_flag_clear(&b->documentBusy); atomic_init(&b->documentRevision,0);
    for (unsigned i=0; i<4; ++i) atomic_init(&b->values[i], 0);
    vhs_bridge_set(b, 0, .24); vhs_bridge_set(b, 1, .08); vhs_bridge_set(b, 2, .62);
    return b;
}
void vhs_bridge_retain(VHSBridge* b) { atomic_fetch_add_explicit(&b->refs, 1, memory_order_relaxed); }
void vhs_bridge_release(VHSBridge* b) {
    if (atomic_fetch_sub_explicit(&b->refs, 1, memory_order_acq_rel) == 1) { vhs_audio_queue_destroy(b->audio); free(b); }
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

int vhs_bridge_store_document(VHSBridge* b, const uint8_t* data, uint32_t count, uint32_t restored) {
    if (count > VHS_STATE_CAPACITY || (count && !data)) return -1;
    if (atomic_flag_test_and_set_explicit(&b->documentBusy,memory_order_acquire)) return -1;
    if (count) memcpy(b->document,data,count);
    b->documentCount=count; b->documentRestored=restored;
    atomic_fetch_add_explicit(&b->documentRevision,1,memory_order_release);
    atomic_flag_clear_explicit(&b->documentBusy,memory_order_release);
    return (int)count;
}
int vhs_bridge_copy_document(VHSBridge* b, uint8_t* data, uint32_t capacity, uint32_t* restored, uint32_t* revision) {
    if (atomic_flag_test_and_set_explicit(&b->documentBusy,memory_order_acquire)) return -1;
    int count = (int)b->documentCount;
    if ((uint32_t)count > capacity || (count && !data)) count=-1;
    else {
        if (count) memcpy(data,b->document,(size_t)count);
        if (restored) *restored=b->documentRestored;
        if (revision) *revision=atomic_load_explicit(&b->documentRevision,memory_order_relaxed);
    }
    atomic_flag_clear_explicit(&b->documentBusy,memory_order_release);
    return count;
}
uint32_t vhs_bridge_document_revision(VHSBridge* b) { return atomic_load_explicit(&b->documentRevision,memory_order_acquire); }
int vhs_bridge_publish_document(VHSBridge* b, const uint8_t* data, uint32_t count, uint32_t expected, uint32_t* published) {
    if (count > VHS_STATE_CAPACITY || (count && !data)) return -1;
    if (atomic_flag_test_and_set_explicit(&b->documentBusy,memory_order_acquire)) return -1;
    if (atomic_load_explicit(&b->documentRevision,memory_order_relaxed) != expected) {
        atomic_flag_clear_explicit(&b->documentBusy,memory_order_release); return -1;
    }
    if (count) memcpy(b->document,data,count);
    b->documentCount=count; b->documentRestored=0;
    uint32_t revision=atomic_fetch_add_explicit(&b->documentRevision,1,memory_order_release)+1;
    if (published) *published=revision;
    atomic_flag_clear_explicit(&b->documentBusy,memory_order_release);
    return (int)count;
}

VHSAudioQueue* vhs_bridge_audio(VHSBridge* b) { return b->audio; }
void vhs_bridge_set_automation(VHSBridge* b,uint32_t slot,double value) {
    if(slot>=VHS_AUTOMATION_SLOTS || !isfinite(value) || value<0 || value>1) return;
    uint64_t bits; memcpy(&bits,&value,8); atomic_store_explicit(&b->automation[slot],bits,memory_order_release);
}
double vhs_bridge_get_automation(VHSBridge* b,uint32_t slot) {
    if(slot>=VHS_AUTOMATION_SLOTS) return 0;
    uint64_t bits=atomic_load_explicit(&b->automation[slot],memory_order_acquire);
    double value; memcpy(&value,&bits,8); return value;
}
// One producer, all payload fields atomic: reader attempts once and never spins.
void vhs_bridge_host_context(VHSBridge* b,VHSHostContext context) {
    uint64_t payload[5];
    memcpy(&payload[0],&context.beats,8); memcpy(&payload[1],&context.tempo,8);
    memcpy(&payload[2],&context.sampleRate,8); memcpy(&payload[3],&context.samplePosition,8);
    payload[4]=context.flags;
    atomic_fetch_add_explicit(&b->hostSequence,1,memory_order_seq_cst);
    for(unsigned i=0;i<5;++i) atomic_store_explicit(&b->host[i],payload[i],memory_order_seq_cst);
    atomic_fetch_add_explicit(&b->hostSequence,1,memory_order_seq_cst);
}
int vhs_bridge_copy_host_context(VHSBridge* b,VHSHostContext* out,uint32_t* revision) {
    unsigned before=atomic_load_explicit(&b->hostSequence,memory_order_seq_cst);
    if(!out || !before || (before&1)) return 0;
    uint64_t payload[5];
    for(unsigned i=0;i<5;++i) payload[i]=atomic_load_explicit(&b->host[i],memory_order_seq_cst);
    if(before!=atomic_load_explicit(&b->hostSequence,memory_order_seq_cst)) return 0;
    memcpy(&out->beats,&payload[0],8); memcpy(&out->tempo,&payload[1],8);
    memcpy(&out->sampleRate,&payload[2],8); memcpy(&out->samplePosition,&payload[3],8); out->flags=(uint32_t)payload[4];
    if(revision) *revision=before;
    return 1;
}

void vhs_bridge_set_bypass(VHSBridge* b,uint32_t value) { atomic_store_explicit(&b->bypass,value!=0,memory_order_release); }
uint32_t vhs_bridge_get_bypass(VHSBridge* b) { return atomic_load_explicit(&b->bypass,memory_order_acquire); }
int vhs_bridge_restore_state(VHSBridge* b,const uint8_t* data,uint32_t count,const double* colors,const double* slots,uint32_t bypass) {
    if(count>VHS_STATE_CAPACITY || (count && !data) || !colors || !slots) return -1;
    for(unsigned i=0;i<3;++i) if(!isfinite(colors[i]) || colors[i]<0 || colors[i]>1) return -1;
    for(unsigned i=0;i<VHS_AUTOMATION_SLOTS;++i) if(!isfinite(slots[i]) || slots[i]<0 || slots[i]>1) return -1;
    if(atomic_flag_test_and_set_explicit(&b->documentBusy,memory_order_acquire)) return -1;
    if(count) memcpy(b->document,data,count);
    b->documentCount=count; b->documentRestored=1;
    for(unsigned i=0;i<3;++i) vhs_bridge_set(b,i,colors[i]);
    for(unsigned i=0;i<VHS_AUTOMATION_SLOTS;++i) vhs_bridge_set_automation(b,i,slots[i]);
    vhs_bridge_set_bypass(b,bypass);
    atomic_fetch_add_explicit(&b->documentRevision,1,memory_order_release);
    atomic_flag_clear_explicit(&b->documentBusy,memory_order_release);
    return (int)count;
}
