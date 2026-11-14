#pragma once
#include <CoreMedia/CoreMedia.h>
#include "VHSInputQueues.h"
#ifdef __cplusplus
extern "C" {
#endif
typedef void* VHSSystemSession;
enum VHSSystemState { VHSSystemOff=0, VHSSystemPicking=1, VHSSystemStarting=2,
    VHSSystemCapturing=3, VHSSystemCancelled=4, VHSSystemDenied=5,
    VHSSystemFailed=6, VHSSystemEnded=7, VHSSystemStopping=8 };
// Control-thread ownership. No picker/stream is created until present is called.
VHSSystemSession vhs_system_create(void);
void vhs_system_present(VHSSystemSession);
void vhs_system_stop(VHSSystemSession);
void vhs_system_release(VHSSystemSession);
int32_t vhs_system_state(VHSSystemSession);
int32_t vhs_system_error(VHSSystemSession);
// Queue lifetime is owned by session AND native stream receivers, including in-flight callbacks.
VHSAudioQueue* vhs_system_queue(VHSSystemSession);

// Native PCM receiver, also exercised without any capture/permission in fixtures.
typedef void* VHSSystemReceiver;
VHSSystemReceiver vhs_system_receiver_create(void);
void vhs_system_receiver_release(VHSSystemReceiver);
VHSAudioQueue* vhs_system_receiver_queue(VHSSystemReceiver);
void vhs_system_receiver_enable(VHSSystemReceiver, int enabled);
void vhs_system_receiver_output(VHSSystemReceiver, CMSampleBufferRef, int32_t outputType);
int32_t vhs_system_receiver_error(VHSSystemReceiver);
#ifdef __cplusplus
}
#endif
