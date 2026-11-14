#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// Single producer, single consumer PER queue. Allocate/destroy only while stopped.
// Push/pop never allocate, lock, spin, invoke callbacks, or access UI/devices.
#define VHS_AUDIO_CHUNK_FRAMES 512
#define VHS_INPUT_QUEUE_SLOTS 64
#define VHS_AUDIO_MAX_BLOCK 8192
#define VHS_MIDI_PACKET_BYTES 256
typedef struct VHSAudioQueue VHSAudioQueue;
typedef struct VHSAudioChunk {
    double sampleRate;
    int64_t sampleTime;
    uint32_t frames, channels, generation;
    float samples[VHS_AUDIO_CHUNK_FRAMES * 2]; // interleaved, channels 1 or 2
} VHSAudioChunk;
VHSAudioQueue* vhs_audio_queue_create(void);
void vhs_audio_queue_destroy(VHSAudioQueue*);
// Whole block is accepted or rejected. Rejection advances the discontinuity generation.
int vhs_audio_push_interleaved(VHSAudioQueue*, const float*, uint32_t frames,
                               uint32_t channels, double sampleRate, int64_t sampleTime);
int vhs_audio_push_planar(VHSAudioQueue*, const float* left, const float* right,
                        uint32_t frames, double sampleRate, int64_t sampleTime);
// Producer-only discontinuity (stop/disconnect/seek). Does not clear consumer storage.
void vhs_audio_mark_gap(VHSAudioQueue*);
int vhs_audio_pop(VHSAudioQueue*, VHSAudioChunk*);
uint32_t vhs_audio_dropped(VHSAudioQueue*);
uint32_t vhs_audio_generation(VHSAudioQueue*);

typedef struct VHSMIDIQueue VHSMIDIQueue;
typedef struct VHSMIDIPacket {
    int64_t sampleTime;
    int32_t offset;
    uint32_t count, generation;
    uint8_t bytes[VHS_MIDI_PACKET_BYTES];
} VHSMIDIPacket;
VHSMIDIQueue* vhs_midi_queue_create(void);
void vhs_midi_queue_destroy(VHSMIDIQueue*);
int vhs_midi_push(VHSMIDIQueue*, const uint8_t*, uint32_t count, int64_t sampleTime, int32_t offset);
// Producer-only reset/disconnect. Consumer sees a loss epoch and clears held state.
void vhs_midi_mark_gap(VHSMIDIQueue*);
int vhs_midi_pop(VHSMIDIQueue*, VHSMIDIPacket*);
uint32_t vhs_midi_dropped(VHSMIDIQueue*);
#ifdef __cplusplus
}
#endif
