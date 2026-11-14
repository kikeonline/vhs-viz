#pragma once
#include "VHSInputQueues.h"
#ifdef __cplusplus
extern "C" {
#endif
#define VHS_DEVICE_LIMIT 256
typedef struct VHSDeviceInfo {
    uint32_t objectID, channels;
    int32_t uniqueID;
    double sampleRate;
    char uid[256], name[256];
} VHSDeviceInfo;
// Control/worker thread only. Return count, or negative OSStatus/error.
int32_t vhs_list_audio_devices(VHSDeviceInfo*, uint32_t capacity);
int32_t vhs_list_midi_sources(VHSDeviceInfo*, uint32_t capacity);
typedef struct VHSDeviceAudio VHSDeviceAudio;
// Selected channels are zero-based; right=-1 means mono. Queue outlives capture.
VHSDeviceAudio* vhs_device_audio_start(VHSAudioQueue*, uint32_t device, int32_t left, int32_t right, int32_t* status);
void vhs_device_audio_stop(VHSDeviceAudio*);
int32_t vhs_device_audio_error(VHSDeviceAudio*);
// Shared conversion path called by the AUHAL callback. No allocation/UI/locks.
int vhs_device_audio_enqueue(VHSAudioQueue*, const float* left, const float* right,
                            uint32_t frames, double rate, double sampleTime);
typedef struct VHSDeviceMIDI VHSDeviceMIDI;
VHSDeviceMIDI* vhs_device_midi_start(VHSMIDIQueue*, uint32_t endpoint, int32_t* status);
void vhs_device_midi_stop(VHSDeviceMIDI*);
#ifdef __cplusplus
}
#endif
