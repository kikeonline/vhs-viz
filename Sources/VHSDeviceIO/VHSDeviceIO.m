#include "VHSDeviceIO.h"
#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreMIDI/CoreMIDI.h>
#include <mach/mach_time.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <limits.h>
#include <stddef.h>
_Static_assert(ATOMIC_INT_LOCK_FREE == 2 && ATOMIC_BOOL_LOCK_FREE == 2, "Lock-free callback state required");

static OSStatus get_property(AudioObjectID object, AudioObjectPropertySelector selector,
                             AudioObjectPropertyScope scope, void* out, UInt32* size) {
    AudioObjectPropertyAddress address={selector,scope,kAudioObjectPropertyElementMain};
    return AudioObjectGetPropertyData(object,&address,0,NULL,size,out);
}
static int audio_string(AudioObjectID object, AudioObjectPropertySelector selector, char* out, size_t capacity) {
    CFStringRef value=NULL; UInt32 size=sizeof(value);
    if (get_property(object,selector,kAudioObjectPropertyScopeGlobal,&value,&size) || !value) return 0;
    Boolean ok=CFStringGetCString(value,out,(CFIndex)capacity,kCFStringEncodingUTF8);
    CFRelease(value); return ok;
}
int32_t vhs_list_audio_devices(VHSDeviceInfo* out, uint32_t capacity) {
    AudioObjectPropertyAddress address={kAudioHardwarePropertyDevices,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
    UInt32 size=0; OSStatus status=AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&address,0,NULL,&size);
    if (status) return status>0 ? -status : status;
    AudioDeviceID* devices=malloc(size ? size : sizeof(AudioDeviceID));
    if (!devices) return memFullErr;
    status=AudioObjectGetPropertyData(kAudioObjectSystemObject,&address,0,NULL,&size,devices);
    if (status) { free(devices); return status>0 ? -status : status; }
    uint32_t found=0;
    for (uint32_t i=0;i<size/sizeof(*devices) && found<capacity;i++) {
        AudioObjectPropertyAddress stream={kAudioDevicePropertyStreamConfiguration,kAudioDevicePropertyScopeInput,kAudioObjectPropertyElementMain};
        UInt32 bytes=0;
        if (AudioObjectGetPropertyDataSize(devices[i],&stream,0,NULL,&bytes) || !bytes) continue;
        AudioBufferList* buffers=malloc(bytes);
        if (!buffers) continue;
        uint32_t channels=0;
        if (!AudioObjectGetPropertyData(devices[i],&stream,0,NULL,&bytes,buffers)) {
            for (uint32_t j=0;j<buffers->mNumberBuffers;j++) channels+=buffers->mBuffers[j].mNumberChannels;
        }
        free(buffers); if (!channels) continue;
        VHSDeviceInfo info={0}; info.objectID=devices[i]; info.channels=channels;
        if (!audio_string(devices[i],kAudioDevicePropertyDeviceUID,info.uid,sizeof(info.uid)) ||
            !audio_string(devices[i],kAudioObjectPropertyName,info.name,sizeof(info.name))) continue;
        UInt32 rateSize=sizeof(info.sampleRate);
        if (get_property(devices[i],kAudioDevicePropertyNominalSampleRate,kAudioObjectPropertyScopeGlobal,&info.sampleRate,&rateSize)) continue;
        out[found++]=info;
    }
    free(devices); return (int32_t)found;
}
int32_t vhs_list_midi_sources(VHSDeviceInfo* out, uint32_t capacity) {
    uint32_t found=0; ItemCount count=MIDIGetNumberOfSources();
    for (ItemCount i=0;i<count && found<capacity;i++) {
        MIDIEndpointRef endpoint=MIDIGetSource(i); VHSDeviceInfo info={0}; CFStringRef name=NULL;
        if (!endpoint || MIDIObjectGetIntegerProperty(endpoint,kMIDIPropertyUniqueID,&info.uniqueID)) continue;
        if (MIDIObjectGetStringProperty(endpoint,kMIDIPropertyDisplayName,&name)) continue;
        Boolean ok=name && CFStringGetCString(name,info.name,sizeof(info.name),kCFStringEncodingUTF8);
        if (name) CFRelease(name);
        if (!ok) continue;
        info.objectID=endpoint; out[found++]=info;
    }
    return (int32_t)found;
}

struct VHSDeviceAudio {
    AudioUnit unit;
    VHSAudioQueue* queue;
    double rate;
    uint32_t channels;
    int64_t nextFrame;
    atomic_bool stopping, ready;
    atomic_uint active;
    atomic_int error;
    // AudioBufferList has a flexible one-buffer tail. Allocate a separate 2-buffer object.
    AudioBufferList* buffers;
    float samples[2][VHS_AUDIO_MAX_BLOCK];
};
int vhs_device_audio_enqueue(VHSAudioQueue* queue, const float* left, const float* right,
                            uint32_t frames, double rate, double time) {
    // Int64 max rounds up to 2^63 in double, so use a strict upper comparison.
    if (!isfinite(time) || time < -0x1p63 || time >= 0x1p63 || trunc(time)!=time) {
        vhs_audio_mark_gap(queue); return 0;
    }
    return vhs_audio_push_planar(queue,left,right,frames,rate,(int64_t)time);
}
static OSStatus input_audio(void* context, AudioUnitRenderActionFlags* flags,
                            const AudioTimeStamp* stamp, UInt32 bus, UInt32 frames, AudioBufferList* ignored) {
    (void)bus; (void)ignored;
    VHSDeviceAudio* audio=context;
    if (!atomic_load_explicit(&audio->ready,memory_order_acquire)) return noErr;
    atomic_fetch_add_explicit(&audio->active,1,memory_order_acquire);
    OSStatus status=noErr;
    if (!atomic_load_explicit(&audio->stopping,memory_order_acquire)) {
        if (!frames) goto done;
        if (frames>VHS_AUDIO_MAX_BLOCK) { status=kAudioUnitErr_TooManyFramesToProcess; goto failed; }
        audio->buffers->mNumberBuffers=audio->channels;
        for (uint32_t i=0;i<audio->channels;i++) {
            audio->buffers->mBuffers[i]=(AudioBuffer){1,frames*sizeof(float),audio->samples[i]};
        }
        status=AudioUnitRender(audio->unit,flags,stamp,1,frames,audio->buffers);
        if (status) goto failed;
        double time=(stamp->mFlags & kAudioTimeStampSampleTimeValid) ? stamp->mSampleTime : (double)audio->nextFrame;
        if (vhs_device_audio_enqueue(audio->queue,audio->samples[0],audio->channels==2 ? audio->samples[1] : NULL,frames,audio->rate,time))
            audio->nextFrame=(int64_t)time+frames;
        else audio->nextFrame=0; // next accepted block begins a new generation after loss.
    }
    goto done;
failed:
    atomic_store_explicit(&audio->error,status,memory_order_release);
    vhs_audio_mark_gap(audio->queue);
done:
    atomic_fetch_sub_explicit(&audio->active,1,memory_order_release);
    return status;
}
void vhs_device_audio_stop(VHSDeviceAudio* audio) {
    if (!audio) return;
    atomic_store_explicit(&audio->stopping,1,memory_order_release);
    if (audio->unit) {
        AudioOutputUnitStop(audio->unit);
        AudioUnitUninitialize(audio->unit);
        AudioComponentInstanceDispose(audio->unit);
    }
    // Native disposal prevents new calls. Quiesce in-flight callbacks on this control thread.
    while (atomic_load_explicit(&audio->active,memory_order_acquire)) usleep(1000);
    vhs_audio_mark_gap(audio->queue); free(audio->buffers); free(audio);
}
VHSDeviceAudio* vhs_device_audio_start(VHSAudioQueue* queue, uint32_t device, int32_t left, int32_t right, int32_t* result) {
    *result=paramErr;
    if (!queue || !device || left<0 || right < -1 || right==left) return NULL;
    VHSDeviceAudio* audio=calloc(1,sizeof(*audio));
    if (!audio) { *result=memFullErr; return NULL; }
    audio->queue=queue; audio->channels=right<0 ? 1 : 2;
    atomic_init(&audio->stopping,0); atomic_init(&audio->ready,0); atomic_init(&audio->active,0); atomic_init(&audio->error,0);
    audio->buffers=calloc(1,offsetof(AudioBufferList,mBuffers)+2*sizeof(AudioBuffer));
    OSStatus status=memFullErr;
    if (!audio->buffers) goto failed;
    AudioComponentDescription description={kAudioUnitType_Output,kAudioUnitSubType_HALOutput,kAudioUnitManufacturer_Apple,0,0};
    AudioComponent component=AudioComponentFindNext(NULL,&description);
    if (!component) { status=kAudioUnitErr_FailedInitialization; goto failed; }
    if ((status=AudioComponentInstanceNew(component,&audio->unit))) goto failed;
    UInt32 on=1,off=0,maximum=VHS_AUDIO_MAX_BLOCK;
    if ((status=AudioUnitSetProperty(audio->unit,kAudioOutputUnitProperty_EnableIO,kAudioUnitScope_Input,1,&on,sizeof(on)))) goto failed;
    if ((status=AudioUnitSetProperty(audio->unit,kAudioOutputUnitProperty_EnableIO,kAudioUnitScope_Output,0,&off,sizeof(off)))) goto failed;
    if ((status=AudioUnitSetProperty(audio->unit,kAudioOutputUnitProperty_CurrentDevice,kAudioUnitScope_Global,0,&device,sizeof(device)))) goto failed;
    AudioStreamBasicDescription native={0}; UInt32 size=sizeof(native);
    if ((status=AudioUnitGetProperty(audio->unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input,1,&native,&size))) goto failed;
    if (!isfinite(native.mSampleRate) || native.mSampleRate<8000 || native.mSampleRate>192000 ||
        (uint32_t)left>=native.mChannelsPerFrame || (right>=0 && (uint32_t)right>=native.mChannelsPerFrame)) { status=kAudioUnitErr_FormatNotSupported; goto failed; }
    audio->rate=native.mSampleRate;
    AudioStreamBasicDescription format={audio->rate,kAudioFormatLinearPCM,kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
        sizeof(float),1,sizeof(float),audio->channels,32,0};
    if ((status=AudioUnitSetProperty(audio->unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output,1,&format,sizeof(format)))) goto failed;
    if ((status=AudioUnitSetProperty(audio->unit,kAudioUnitProperty_ShouldAllocateBuffer,kAudioUnitScope_Output,1,&off,sizeof(off)))) goto failed;
    SInt32 map[2]={left,right};
    if ((status=AudioUnitSetProperty(audio->unit,kAudioOutputUnitProperty_ChannelMap,kAudioUnitScope_Output,1,map,audio->channels*sizeof(SInt32)))) goto failed;
    if ((status=AudioUnitSetProperty(audio->unit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global,0,&maximum,sizeof(maximum)))) goto failed;
    AURenderCallbackStruct callback={input_audio,audio};
    if ((status=AudioUnitSetProperty(audio->unit,kAudioOutputUnitProperty_SetInputCallback,kAudioUnitScope_Global,0,&callback,sizeof(callback)))) goto failed;
    if ((status=AudioUnitInitialize(audio->unit))) goto failed;
    // Publish all callback state explicitly across the native framework boundary.
    atomic_store_explicit(&audio->ready,1,memory_order_release);
    if ((status=AudioOutputUnitStart(audio->unit))) goto failed;
    *result=0; return audio;
failed:
    *result=status; vhs_device_audio_stop(audio); return NULL;
}
int32_t vhs_device_audio_error(VHSDeviceAudio* audio) { return atomic_load_explicit(&audio->error,memory_order_acquire); }

struct VHSDeviceMIDI {
    MIDIClientRef client; MIDIPortRef port;
    VHSMIDIQueue* queue;
    double ticksToFrames;
    atomic_bool stopping, ready;
    atomic_uint active;
    atomic_flag delivering;
};
static void input_midi(VHSDeviceMIDI* midi, const MIDIEventList* list) {
    if (!atomic_load_explicit(&midi->ready,memory_order_acquire)) return;
    atomic_fetch_add_explicit(&midi->active,1,memory_order_acquire);
    if (atomic_load_explicit(&midi->stopping,memory_order_acquire)) goto done;
    // Core MIDI normally serializes a client's input. Reject any reentrant delivery
    // instead of permitting two simultaneous SPSC writers. Never wait on the callback.
    if (atomic_flag_test_and_set_explicit(&midi->delivering,memory_order_acquire)) {
        vhs_midi_mark_gap(midi->queue); goto done;
    }
    const MIDIEventPacket* packet=&list->packet[0]; uint32_t budget=4096;
    if (list->numPackets>256) { vhs_midi_mark_gap(midi->queue); goto unlock; }
    for (uint32_t p=0;p<list->numPackets;p++,packet=MIDIEventPacketNext(packet)) {
        if (packet->wordCount>budget) { vhs_midi_mark_gap(midi->queue); goto unlock; }
        budget-=packet->wordCount;
        uint64_t stamp=packet->timeStamp ? packet->timeStamp : mach_absolute_time();
        double frames=(double)stamp*midi->ticksToFrames;
        int64_t time=frames>=0x1p63 ? INT64_MAX : (int64_t)frames;
        for (uint32_t w=0;w<packet->wordCount;) {
            uint32_t word=packet->words[w], type=word>>28;
            static const uint8_t sizes[16]={1,1,1,2,2,4,1,1,2,2,2,3,3,4,4,4};
            uint32_t step=sizes[type];
            if (step>packet->wordCount-w) { vhs_midi_mark_gap(midi->queue); goto unlock; }
            uint8_t status=(word>>16)&255, bytes[3]={status,(word>>8)&127,word&127};
            if (type==2 && status>=0x80 && status<0xF0) {
                uint32_t length=(status & 0xE0)==0xC0 ? 2 : 3;
                vhs_midi_push(midi->queue,bytes,length,time,0);
            } else if (type==1 && status==0xFF) vhs_midi_push(midi->queue,bytes,1,time,0);
            w+=step;
        }
    }
unlock:
    atomic_flag_clear_explicit(&midi->delivering,memory_order_release);
done:
    atomic_fetch_sub_explicit(&midi->active,1,memory_order_release);
}
void vhs_device_midi_stop(VHSDeviceMIDI* midi) {
    if (!midi) return;
    atomic_store_explicit(&midi->stopping,1,memory_order_release);
    if (midi->port) MIDIPortDispose(midi->port);
    if (midi->client) MIDIClientDispose(midi->client);
    while (atomic_load_explicit(&midi->active,memory_order_acquire)) usleep(1000);
    vhs_midi_mark_gap(midi->queue); free(midi);
}
VHSDeviceMIDI* vhs_device_midi_start(VHSMIDIQueue* queue, uint32_t endpoint, int32_t* result) {
    *result=paramErr; if (!queue || !endpoint) return NULL;
    VHSDeviceMIDI* midi=calloc(1,sizeof(*midi)); if (!midi) { *result=memFullErr; return NULL; }
    midi->queue=queue; atomic_init(&midi->stopping,0); atomic_init(&midi->ready,0); atomic_init(&midi->active,0); atomic_flag_clear(&midi->delivering);
    mach_timebase_info_data_t timebase; mach_timebase_info(&timebase);
    midi->ticksToFrames=(double)timebase.numer/timebase.denom*48000.0/1e9;
    OSStatus status=MIDIClientCreateWithBlock(CFSTR("VHS input"),&midi->client, ^(const MIDINotification* notification) { (void)notification; });
    if (status) goto failed;
    status=MIDIInputPortCreateWithProtocol(midi->client,CFSTR("VHS MIDI 1.0 input"),kMIDIProtocol_1_0,&midi->port,
        ^(const MIDIEventList* list, void* connection) { (void)connection; input_midi(midi,list); });
    if (status) goto failed;
    // Core MIDI's internal thread handoff is opaque to us. This release/acquire
    // makes context initialization visible before ANY callback field is accessed.
    atomic_store_explicit(&midi->ready,1,memory_order_release);
    if ((status=MIDIPortConnectSource(midi->port,endpoint,NULL))) goto failed;
    *result=0; return midi;
failed:
    *result=status; vhs_device_midi_stop(midi); return NULL;
}
