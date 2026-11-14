#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#include "VHSSystemIO.h"
#include <stdatomic.h>
#include <stddef.h>
#include <math.h>

@interface VHSSystemQueue : NSObject {
@public VHSAudioQueue* queue;
    atomic_int error;
}
@end
@implementation VHSSystemQueue
- (instancetype)init {
    if ((self=[super init])) { queue=vhs_audio_queue_create(); atomic_init(&error,0); if (!queue) return nil; }
    return self;
}
- (void)dealloc { vhs_audio_queue_destroy(queue); }
@end

@interface VHSSystemPCM : NSObject <SCStreamOutput> {
@public VHSSystemQueue* owner; atomic_bool enabled;
}
- (instancetype)initWithOwner:(VHSSystemQueue*)value;
@end

static void ingest(VHSSystemPCM* receiver, CMSampleBufferRef sample, int32_t type) {
    // No video output is registered. Defensive rejection occurs before inspecting video buffers.
    if (type!=SCStreamOutputTypeAudio || !atomic_load_explicit(&receiver->enabled,memory_order_acquire)) return;
    VHSAudioQueue* queue=receiver->owner->queue;
    int32_t fault=-50;
    if (!sample || !CMSampleBufferIsValid(sample) || !CMSampleBufferDataIsReady(sample)) goto invalid;
    CMFormatDescriptionRef description=CMSampleBufferGetFormatDescription(sample);
    if (!description || CMFormatDescriptionGetMediaType(description)!=kCMMediaType_Audio) goto invalid;
    const AudioStreamBasicDescription* format=CMAudioFormatDescriptionGetStreamBasicDescription(description);
    if (!format || format->mFormatID!=kAudioFormatLinearPCM || format->mBitsPerChannel!=32 ||
        !(format->mFormatFlags & kAudioFormatFlagIsFloat) || !(format->mFormatFlags & kAudioFormatFlagIsPacked) ||
        (format->mFormatFlags & kAudioFormatFlagIsBigEndian) ||
        format->mChannelsPerFrame<1 || format->mChannelsPerFrame>2 ||
        !isfinite(format->mSampleRate) || format->mSampleRate<8000 || format->mSampleRate>192000 ||
        trunc(format->mSampleRate)!=format->mSampleRate) goto invalid;
    CMItemCount count=CMSampleBufferGetNumSamples(sample);
    if (count<1 || count>VHS_AUDIO_MAX_BLOCK) goto invalid;
    CMTime stamp=CMSampleBufferGetPresentationTimeStamp(sample);
    if (!CMTIME_IS_NUMERIC(stamp) || stamp.epoch!=0) goto invalid;
    stamp=CMTimeConvertScale(stamp,(int32_t)format->mSampleRate,kCMTimeRoundingMethod_RoundHalfAwayFromZero);
    if (!CMTIME_IS_NUMERIC(stamp)) goto invalid;
    struct { UInt32 number; AudioBuffer buffers[2]; } storage={0};
    CMBlockBufferRef block=NULL;
    size_t listSize=offsetof(AudioBufferList,mBuffers)+sizeof(AudioBuffer)*
        ((format->mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? format->mChannelsPerFrame : 1);
    // Refuse formats that require a new data allocation/contiguity copy in the callback.
    OSStatus result=CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample,NULL,(AudioBufferList*)&storage,
        listSize,kCFAllocatorNull,kCFAllocatorNull,0,&block);
    if (result) { fault=result; goto invalid; }
    int accepted=0;
    uint32_t channels=format->mChannelsPerFrame;
    if (format->mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
        if (storage.number==channels && format->mBytesPerFrame==sizeof(float)) {
            int valid=1;
            for (uint32_t i=0;i<channels;i++) {
                if (storage.buffers[i].mNumberChannels!=1 || !storage.buffers[i].mData || storage.buffers[i].mDataByteSize<(uint32_t)count*sizeof(float)) valid=0;
            }
            if (valid) accepted=vhs_audio_push_planar(queue,storage.buffers[0].mData,channels==2 ? storage.buffers[1].mData : NULL,
                (uint32_t)count,format->mSampleRate,stamp.value);
            else { if (block) CFRelease(block); goto invalid; }
        } else { if (block) CFRelease(block); goto invalid; }
    } else if (storage.number==1 && format->mBytesPerFrame==channels*sizeof(float) &&
               storage.buffers[0].mNumberChannels==channels && storage.buffers[0].mData &&
               storage.buffers[0].mDataByteSize>=(uint32_t)count*channels*sizeof(float)) {
        accepted=vhs_audio_push_interleaved(queue,storage.buffers[0].mData,(uint32_t)count,channels,format->mSampleRate,stamp.value);
    } else { if (block) CFRelease(block); goto invalid; }
    (void)accepted; // Queue overflow carries its own generation/drop counter; it isn't a format failure.
    if (block) CFRelease(block);
    return;
invalid:
    atomic_store_explicit(&receiver->owner->error,fault,memory_order_release);
    vhs_audio_mark_gap(queue);
}
@implementation VHSSystemPCM
- (instancetype)initWithOwner:(VHSSystemQueue*)value {
    if ((self=[super init])) { owner=value; atomic_init(&enabled,0); }
    return self;
}
- (void)stream:(SCStream*)stream didOutputSampleBuffer:(CMSampleBufferRef)sample ofType:(SCStreamOutputType)type {
    (void)stream; ingest(self,sample,(int32_t)type);
}
@end
VHSSystemReceiver vhs_system_receiver_create(void) {
    VHSSystemQueue* owner=[VHSSystemQueue new];
    return owner ? (__bridge_retained void*)[[VHSSystemPCM alloc] initWithOwner:owner] : NULL;
}
void vhs_system_receiver_release(VHSSystemReceiver value) { if (value) { id released=(__bridge_transfer id)value; (void)released; } }
VHSAudioQueue* vhs_system_receiver_queue(VHSSystemReceiver value) { return ((__bridge VHSSystemPCM*)value)->owner->queue; }
void vhs_system_receiver_enable(VHSSystemReceiver value,int enabled) { atomic_store_explicit(&((__bridge VHSSystemPCM*)value)->enabled,enabled!=0,memory_order_release); }
void vhs_system_receiver_output(VHSSystemReceiver value,CMSampleBufferRef sample,int32_t type) { ingest((__bridge VHSSystemPCM*)value,sample,type); }
int32_t vhs_system_receiver_error(VHSSystemReceiver value) { return atomic_load_explicit(&((__bridge VHSSystemPCM*)value)->owner->error,memory_order_acquire); }

@class VHSSystemCapture;
@interface VHSSharingRequest : NSObject <SCContentSharingPickerObserver>
@property(nonatomic,weak) VHSSystemCapture* owner;
@property(nonatomic) unsigned generation;
@end
@interface VHSSystemCapture : NSObject <SCStreamDelegate> {
@public VHSSystemQueue* owner; atomic_int state; atomic_uint generation;
    dispatch_queue_t samples;
    SCStream* stream;
    VHSSystemPCM* receiver;
    VHSSharingRequest* request;
    unsigned streamGeneration;
    BOOL starting, stopping;
    void (^afterStop)(void);
}
- (void)endThen:(void (^)(void))completion;
- (void)finishStop;
- (void)choose:(SCContentFilter*)filter generation:(unsigned)epoch;
- (void)fail:(NSError*)error generation:(unsigned)epoch ended:(BOOL)ended;
- (void)present;
- (void)stop;
@end
@implementation VHSSharingRequest
- (void)contentSharingPicker:(SCContentSharingPicker*)picker didCancelForStream:(SCStream*)stream {
    (void)picker; (void)stream;
    dispatch_async(dispatch_get_main_queue(), ^{
        VHSSystemCapture* capture=self.owner; unsigned epoch=self.generation;
        if (!capture || epoch!=atomic_load(&capture->generation)) return;
        [capture endThen:^{ if (epoch==atomic_load(&capture->generation)) atomic_store(&capture->state,VHSSystemCancelled); }];
    });
}
- (void)contentSharingPicker:(SCContentSharingPicker*)picker didUpdateWithFilter:(SCContentFilter*)filter forStream:(SCStream*)stream {
    (void)picker;
    dispatch_async(dispatch_get_main_queue(), ^{ if (!stream) [self.owner choose:filter generation:self.generation]; });
}
- (void)contentSharingPickerStartDidFailWithError:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{ [self.owner fail:error generation:self.generation ended:NO]; });
}
@end

@implementation VHSSystemCapture
- (instancetype)init {
    if ((self=[super init])) {
        owner=[VHSSystemQueue new]; if (!owner) return nil;
        samples=dispatch_queue_create("VHS system PCM",DISPATCH_QUEUE_SERIAL);
        atomic_init(&state,VHSSystemOff); atomic_init(&generation,0);
    }
    return self;
}
- (void)endThen:(void (^)(void))completion {
    // Main-thread lifecycle only; callbacks touch only receiver/queue atomics.
    if (request) {
        [[SCContentSharingPicker sharedPicker] removeObserver:request];
        [SCContentSharingPicker sharedPicker].active=NO; request=nil;
    }
    if (receiver) atomic_store_explicit(&receiver->enabled,0,memory_order_release);
    afterStop=completion;
    if (!starting) [self finishStop];
}
- (void)finishStop {
    if (stopping) return;
    SCStream* previous=stream; VHSSystemPCM* output=receiver;
    stream=nil; receiver=nil;
    void (^finish)(void)=^{
        if (previous && output) [previous removeStreamOutput:output type:SCStreamOutputTypeAudio error:NULL];
        // Control-thread barrier: copies already in flight finish before the generation reset.
        dispatch_sync(self->samples, ^{ vhs_audio_mark_gap(self->owner->queue); });
        self->stopping=NO;
        void (^continuation)(void)=self->afterStop; self->afterStop=nil;
        if (continuation) continuation();
    };
    if (previous) {
        stopping=YES;
        [previous stopCaptureWithCompletionHandler:^(NSError* error) { (void)error; dispatch_async(dispatch_get_main_queue(),finish); }];
    } else finish();
}
- (void)present {
    unsigned epoch=atomic_fetch_add_explicit(&generation,1,memory_order_acq_rel)+1;
    atomic_store_explicit(&state,VHSSystemPicking,memory_order_release);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self endThen:^{
            if (epoch!=atomic_load(&self->generation)) return;
            atomic_store(&self->owner->error,0);
            VHSSharingRequest* observer=[VHSSharingRequest new]; observer.owner=self; observer.generation=epoch;
            self->request=observer;
            SCContentSharingPicker* picker=[SCContentSharingPicker sharedPicker];
            SCContentSharingPickerConfiguration* configuration=[SCContentSharingPickerConfiguration new];
            configuration.allowedPickerModes=SCContentSharingPickerModeSingleApplication | SCContentSharingPickerModeSingleDisplay;
            configuration.allowsChangingSelectedContent=NO;
            picker.defaultConfiguration=configuration; picker.maximumStreamCount=@1;
            [picker addObserver:observer]; picker.active=YES;
            [picker presentPickerUsingContentStyle:SCShareableContentStyleApplication];
        }];
    });
}
- (void)stop {
    unsigned epoch=atomic_fetch_add_explicit(&generation,1,memory_order_acq_rel)+1;
    atomic_store_explicit(&state,VHSSystemStopping,memory_order_release);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self endThen:^{ if (epoch==atomic_load(&self->generation)) atomic_store_explicit(&self->state,VHSSystemOff,memory_order_release); }];
    });
}
- (void)choose:(SCContentFilter*)filter generation:(unsigned)epoch {
    if (epoch!=atomic_load(&generation) || stream || starting || stopping || atomic_load(&state)!=VHSSystemPicking) return;
    // Opt-in attended verification; runs on the control thread, never an audio callback.
    if (getenv("VHS_CAPTURE_DIAGNOSTICS")) {
        for (SCRunningApplication* app in filter.includedApplications)
            NSLog(@"VHS shared application %@ pid=%d",app.bundleIdentifier,app.processID);
        NSLog(@"VHS sharing style=%ld",(long)filter.style);
    }
    atomic_store(&state,VHSSystemStarting); atomic_store(&owner->error,0);
    SCStreamConfiguration* config=[SCStreamConfiguration new];
    config.capturesAudio=YES; config.captureMicrophone=NO; config.excludesCurrentProcessAudio=YES;
    config.sampleRate=48000; config.channelCount=2;
    config.width=16; config.height=16; config.minimumFrameInterval=CMTimeMake(1,1); config.queueDepth=3; config.showsCursor=NO;
    receiver=[[VHSSystemPCM alloc] initWithOwner:owner];
    SCStream* candidate=[[SCStream alloc] initWithFilter:filter configuration:config delegate:self];
    stream=candidate; streamGeneration=epoch;
    NSError* error=nil;
    if (![candidate addStreamOutput:receiver type:SCStreamOutputTypeAudio sampleHandlerQueue:samples error:&error]) {
        [self fail:error generation:epoch ended:NO]; return;
    }
    atomic_store_explicit(&receiver->enabled,1,memory_order_release);
    starting=YES;
    [candidate startCaptureWithCompletionHandler:^(NSError* error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->starting=NO;
            if (epoch!=atomic_load(&self->generation) || self->afterStop) { [self finishStop]; return; }
            if (error) [self fail:error generation:epoch ended:NO];
            else atomic_store_explicit(&self->state,VHSSystemCapturing,memory_order_release);
        });
    }];
}
- (void)fail:(NSError*)error generation:(unsigned)epoch ended:(BOOL)ended {
    if (epoch!=atomic_load(&generation)) return;
    int code=error ? (int)error.code : -1;
    int status=ended ? VHSSystemEnded : (code==SCStreamErrorUserDeclined ? VHSSystemDenied : VHSSystemFailed);
    [self endThen:^{
        if (epoch!=atomic_load(&self->generation)) return;
        atomic_store(&self->owner->error,code); atomic_store_explicit(&self->state,status,memory_order_release);
    }];
}
- (void)stream:(SCStream*)source didStopWithError:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (source!=self->stream) return;
        BOOL ended=error.code==SCStreamErrorUserStopped || error.code==SCStreamErrorSystemStoppedStream;
        // A newer request may already have advanced generation on the worker,
        // before its main-queue teardown runs. Never attribute an old stream's
        // termination to that new request.
        [self fail:error generation:self->streamGeneration ended:ended];
    });
}
@end
VHSSystemSession vhs_system_create(void) { return (__bridge_retained void*)[VHSSystemCapture new]; }
void vhs_system_present(VHSSystemSession value) { [(__bridge VHSSystemCapture*)value present]; }
void vhs_system_stop(VHSSystemSession value) { [(__bridge VHSSystemCapture*)value stop]; }
void vhs_system_release(VHSSystemSession value) {
    if (!value) return;
    VHSSystemCapture* capture=(__bridge_transfer VHSSystemCapture*)value;
    if (atomic_load(&capture->state)!=VHSSystemOff) [capture stop];
}
int32_t vhs_system_state(VHSSystemSession value) { return atomic_load_explicit(&((__bridge VHSSystemCapture*)value)->state,memory_order_acquire); }
int32_t vhs_system_error(VHSSystemSession value) { return atomic_load_explicit(&((__bridge VHSSystemCapture*)value)->owner->error,memory_order_acquire); }
VHSAudioQueue* vhs_system_queue(VHSSystemSession value) { return ((__bridge VHSSystemCapture*)value)->owner->queue; }
