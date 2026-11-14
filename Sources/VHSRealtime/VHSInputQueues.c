#include "VHSInputQueues.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <limits.h>
_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "Lock-free queue indices required");
struct VHSAudioQueue {
    atomic_uint read, write, dropped;
    atomic_uint generation;
    VHSAudioChunk slots[VHS_INPUT_QUEUE_SLOTS];
};
struct VHSMIDIQueue {
    atomic_uint read, write, dropped;
    VHSMIDIPacket slots[VHS_INPUT_QUEUE_SLOTS];
};
VHSAudioQueue* vhs_audio_queue_create(void) {
    VHSAudioQueue* q = calloc(1, sizeof(*q));
    if (q) { atomic_init(&q->read,0); atomic_init(&q->write,0); atomic_init(&q->dropped,0); atomic_init(&q->generation,0); }
    return q;
}
void vhs_audio_queue_destroy(VHSAudioQueue* q) { free(q); }
void vhs_audio_mark_gap(VHSAudioQueue* q) { atomic_fetch_add_explicit(&q->generation,1,memory_order_release); }
uint32_t vhs_audio_generation(VHSAudioQueue* q) { return atomic_load_explicit(&q->generation,memory_order_acquire); }
static int audio_push(VHSAudioQueue* q, const float* a, const float* b, uint32_t frames,
                      uint32_t channels, double rate, int64_t time, int planar) {
    unsigned w = atomic_load_explicit(&q->write,memory_order_relaxed);
    unsigned r = atomic_load_explicit(&q->read,memory_order_acquire);
    unsigned needed = frames / VHS_AUDIO_CHUNK_FRAMES + (frames % VHS_AUDIO_CHUNK_FRAMES != 0);
    if (!a || !frames || frames > VHS_AUDIO_MAX_BLOCK || channels < 1 || channels > 2 ||
        !isfinite(rate) || rate < 8000 || rate > 192000 || time > INT64_MAX-(int64_t)frames ||
        needed > VHS_INPUT_QUEUE_SLOTS-(w-r)) {
        vhs_audio_mark_gap(q);
        atomic_fetch_add_explicit(&q->dropped,1,memory_order_relaxed);
        return 0;
    }
    for (unsigned chunk=0, start=0; chunk<needed; ++chunk, start+=VHS_AUDIO_CHUNK_FRAMES) {
        VHSAudioChunk* s = &q->slots[(w+chunk)%VHS_INPUT_QUEUE_SLOTS];
        unsigned count = frames-start;
        if (count > VHS_AUDIO_CHUNK_FRAMES) count=VHS_AUDIO_CHUNK_FRAMES;
        s->sampleRate=rate; s->sampleTime=time+start; s->frames=count;
        s->channels=channels; s->generation=atomic_load_explicit(&q->generation,memory_order_relaxed);
        if (!planar) memcpy(s->samples,a+start*channels,count*channels*sizeof(float));
        else for (unsigned i=0; i<count; ++i) {
            s->samples[i*channels]=a[start+i];
            if (channels==2) s->samples[i*2+1]=b[start+i];
        }
    }
    // Publish all chunks together; no partial callback can enter the consumer.
    atomic_store_explicit(&q->write,w+needed,memory_order_release);
    return 1;
}
int vhs_audio_push_interleaved(VHSAudioQueue* q, const float* data, uint32_t frames,
                               uint32_t channels, double rate, int64_t time) {
    return audio_push(q,data,NULL,frames,channels,rate,time,0);
}
int vhs_audio_push_planar(VHSAudioQueue* q, const float* left, const float* right,
                        uint32_t frames, double rate, int64_t time) {
    return audio_push(q,left,right,frames,right ? 2 : 1,rate,time,1);
}
int vhs_audio_pop(VHSAudioQueue* q, VHSAudioChunk* out) {
    unsigned r=atomic_load_explicit(&q->read,memory_order_relaxed);
    if (r==atomic_load_explicit(&q->write,memory_order_acquire)) return 0;
    *out=q->slots[r%VHS_INPUT_QUEUE_SLOTS];
    atomic_store_explicit(&q->read,r+1,memory_order_release); return 1;
}
uint32_t vhs_audio_dropped(VHSAudioQueue* q) { return atomic_load_explicit(&q->dropped,memory_order_acquire); }
VHSMIDIQueue* vhs_midi_queue_create(void) {
    VHSMIDIQueue* q=calloc(1,sizeof(*q));
    if (q) { atomic_init(&q->read,0); atomic_init(&q->write,0); atomic_init(&q->dropped,0); }
    return q;
}
void vhs_midi_queue_destroy(VHSMIDIQueue* q) { free(q); }
void vhs_midi_mark_gap(VHSMIDIQueue* q) { atomic_fetch_add_explicit(&q->dropped,1,memory_order_release); }
int vhs_midi_push(VHSMIDIQueue* q, const uint8_t* bytes, uint32_t count, int64_t time, int32_t offset) {
    unsigned w=atomic_load_explicit(&q->write,memory_order_relaxed);
    unsigned r=atomic_load_explicit(&q->read,memory_order_acquire);
    if (!bytes || !count || count>VHS_MIDI_PACKET_BYTES || offset<0 || w-r>=VHS_INPUT_QUEUE_SLOTS) {
        vhs_midi_mark_gap(q); return 0;
    }
    VHSMIDIPacket* s=&q->slots[w%VHS_INPUT_QUEUE_SLOTS];
    s->sampleTime=time; s->offset=offset; s->count=count;
    s->generation=atomic_load_explicit(&q->dropped,memory_order_acquire);
    memcpy(s->bytes,bytes,count);
    atomic_store_explicit(&q->write,w+1,memory_order_release); return 1;
}
int vhs_midi_pop(VHSMIDIQueue* q, VHSMIDIPacket* out) {
    unsigned r=atomic_load_explicit(&q->read,memory_order_relaxed);
    if (r==atomic_load_explicit(&q->write,memory_order_acquire)) return 0;
    *out=q->slots[r%VHS_INPUT_QUEUE_SLOTS];
    atomic_store_explicit(&q->read,r+1,memory_order_release); return 1;
}
uint32_t vhs_midi_dropped(VHSMIDIQueue* q) { return atomic_load_explicit(&q->dropped,memory_order_acquire); }
