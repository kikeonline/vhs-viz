#include "Processor.h"
#include "public.sdk/source/common/pluginview.h"
#include "public.sdk/source/main/pluginfactory.h"
#include "pluginterfaces/vst/ivstevents.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"
#include "base/source/fstreamer.h"
#include "pluginterfaces/base/ustring.h"
#include <cstdio>
#import <AppKit/AppKit.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <array>

@interface VHSProductionBundleMarker : NSObject @end
@implementation VHSProductionBundleMarker @end
extern "C" int vhs_document_validate(const uint8_t*, uint32_t);
extern "C" void* vhs_ui_create(VHSBridge*, const char*);
extern "C" void* vhs_ui_attach(void*, void*);
extern "C" void vhs_ui_detach(void*);
extern "C" void vhs_ui_destroy(void*);
namespace VHS {
class Editor final : public CPluginView {
    IPtr<Processor> owner;
    void* runtime;
    void* view = nullptr;
public:
    Editor(Processor* owner, void* runtime): owner(owner), runtime(runtime) { rect = {0,0,1000,720}; }
    ~Editor() override { if (view) vhs_ui_detach(view); }
    tresult PLUGIN_API isPlatformTypeSupported(FIDString type) override {
        return type && std::strcmp(type, kPlatformTypeNSView) == 0 ? kResultTrue : kResultFalse;
    }
    tresult PLUGIN_API attached(void* parent, FIDString type) override {
        if (!parent || view || isPlatformTypeSupported(type) != kResultTrue) return kResultFalse;
        view = vhs_ui_attach(runtime, parent);
        if (!view) return kResultFalse;
        return CPluginView::attached(parent, type);
    }
    tresult PLUGIN_API removed() override {
        if (view) { vhs_ui_detach(view); view = nullptr; }
        return CPluginView::removed();
    }
};
Processor::Processor(): bridge(vhs_bridge_create()) {
    processContextRequirements.needTempo().needTransportState().needSystemTime().needProjectTimeMusic();
}
uint32 PLUGIN_API Processor::release() {
    // Keep final UI/controller teardown on the main thread even if the host
    // releases its last reference from a worker. This never waits on the worker.
    if([NSThread isMainThread]) return SingleComponentEffect::release();
    SingleComponentEffect::addRef();
    dispatch_async(dispatch_get_main_queue(), ^{ this->SingleComponentEffect::release(); });
    return SingleComponentEffect::release();
}
Processor::~Processor() {
    if (bridge) {
        vhs_bridge_callback(bridge, nullptr, nullptr);
        if (runtime) vhs_ui_destroy(runtime);
        vhs_bridge_release(bridge);
    }
}
tresult PLUGIN_API Processor::initialize(FUnknown* context) {
    if (!bridge) return kOutOfMemory;
    auto result = SingleComponentEffect::initialize(context);
    if (result != kResultOk) return result;
    addAudioInput(STR16("Stereo In"), SpeakerArr::kStereo);
    addAudioOutput(STR16("Stereo Out"), SpeakerArr::kStereo);
    addEventInput(STR16("Visual MIDI"), 16);
    parameters.addParameter(STR16("Solid Red"), nullptr, 0, .24, ParameterInfo::kCanAutomate, 0);
    parameters.addParameter(STR16("Solid Green"), nullptr, 0, .08, ParameterInfo::kCanAutomate, 1);
    parameters.addParameter(STR16("Solid Blue"), nullptr, 0, .62, ParameterInfo::kCanAutomate, 2);
    parameters.addParameter(STR16("Reserved CC1 status"), nullptr, 0, 0, ParameterInfo::kIsHidden, 3);
    parameters.addParameter(STR16("Bypass"),nullptr,1,0,ParameterInfo::kCanAutomate|ParameterInfo::kIsBypass,0x3000);
    for(uint32 i=0;i<VHS_AUTOMATION_SLOTS;++i) {
        String128 title{}; char text[32]; std::snprintf(text,sizeof(text),"Visual %02u",i+1);
        UString(title,128).fromAscii(text);
        parameters.addParameter(title,nullptr,0,0,ParameterInfo::kCanAutomate,VHS_AUTOMATION_FIRST+i);
    }
    // A fixed controller discovery bank lets the host translate unassigned CCs
    // without relying on raw MIDI CC bytes in IEventList. Never renumber it.
    for(int ch=0;ch<16;++ch) for(int cc=0;cc<128;++cc) {
        String128 title{};
        char text[64]; std::snprintf(text,sizeof(text),"MIDI %d CC%d",ch+1,cc);
        UString(title,128).fromAscii(text);
        parameters.addParameter(title,nullptr,0,0,ParameterInfo::kIsHidden,0x1000+ch*128+cc);
    }
    return kResultOk;
}
tresult PLUGIN_API Processor::terminate() {
    vhs_bridge_callback(bridge, nullptr, nullptr);
    if (runtime) { vhs_ui_destroy(runtime); runtime = nullptr; }
    return SingleComponentEffect::terminate();
}
tresult PLUGIN_API Processor::queryInterface(const TUID iid, void** obj) {
    QUERY_INTERFACE(iid, obj, IMidiMapping::iid, IMidiMapping)
    return SingleComponentEffect::queryInterface(iid, obj);
}
tresult PLUGIN_API Processor::getMidiControllerAssignment(int32 bus, int16 channel, CtrlNumber cc, ParamID& id) {
    if (bus == 0 && channel >= 0 && channel < 16 && cc >= 0 && cc < 128) { id=0x1000+channel*128+cc; return kResultTrue; }
    return kResultFalse;
}
tresult PLUGIN_API Processor::setParamNormalized(ParamID id, ParamValue value) {
    if (!std::isfinite(value) || value < 0 || value > 1) return kInvalidArgument;
    if(id>=0x1000 && id<0x1800) return SingleComponentEffect::setParamNormalized(id,value);
    if(id>=VHS_AUTOMATION_FIRST && id<VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS) {
        vhs_bridge_set_automation(bridge,id-VHS_AUTOMATION_FIRST,value);
        return SingleComponentEffect::setParamNormalized(id,value);
    }
    if(id==0x3000) { vhs_bridge_set_bypass(bridge,value>=0.5); return SingleComponentEffect::setParamNormalized(id,value); }
    if(id>3) return kInvalidArgument;
    vhs_bridge_set(bridge, id, value);
    return SingleComponentEffect::setParamNormalized(id, value);
}
ParamValue PLUGIN_API Processor::getParamNormalized(ParamID id) {
    if(id<4) return vhs_bridge_get(bridge,id);
    if(id==0x3000) return vhs_bridge_get_bypass(bridge);
    if(id>=VHS_AUTOMATION_FIRST && id<VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS)
        return vhs_bridge_get_automation(bridge,id-VHS_AUTOMATION_FIRST);
    return SingleComponentEffect::getParamNormalized(id);
}
tresult PLUGIN_API Processor::setupProcessing(ProcessSetup& setup) {
    if(!std::isfinite(setup.sampleRate) || setup.sampleRate<8000 || setup.sampleRate>192000 || setup.maxSamplesPerBlock<0)
        return kInvalidArgument;
    resetPending=true;
    return SingleComponentEffect::setupProcessing(setup);
}
tresult PLUGIN_API Processor::canProcessSampleSize(int32 size) { return size == kSample32 || size == kSample64 ? kResultTrue : kResultFalse; }
tresult PLUGIN_API Processor::setBusArrangements(SpeakerArrangement* ins,int32 ni,SpeakerArrangement* outs,int32 no) {
    if(ni!=1 || no!=1 || !ins || !outs || ins[0]!=outs[0] || (ins[0]!=SpeakerArr::kStereo && ins[0]!=SpeakerArr::kMono)) return kResultFalse;
    auto* input=static_cast<AudioBus*>(audioInputs.at(0).get());
    auto* output=static_cast<AudioBus*>(audioOutputs.at(0).get());
    if(!input || !output) return kResultFalse;
    input->setArrangement(ins[0]); output->setArrangement(outs[0]); return kResultOk;
}
tresult PLUGIN_API Processor::setProcessing(TBool) { resetPending=true; return kResultOk; }
tresult PLUGIN_API Processor::setActive(TBool state) { resetPending=true; return SingleComponentEffect::setActive(state); }
// Analysis conversion is preallocated and separate from byte-preserving audio output.
template<class Sample> double pass(AudioBusBuffers& in,AudioBusBuffers& out,int32 count,Sample** src,Sample** dst,
                                   float* left,float* right) {
    double peak=0;
    for(int32 ch=0;ch<out.numChannels;++ch) {
        const bool silent=(in.silenceFlags & (uint64(1)<<ch))!=0 || !src[ch];
        if(dst[ch]) {
            if(silent) std::memset(dst[ch],0,size_t(count)*sizeof(Sample));
            else if(src[ch]!=dst[ch]) std::memmove(dst[ch],src[ch],size_t(count)*sizeof(Sample));
        }
        if(count<=VHS_AUDIO_MAX_BLOCK) for(int32 i=0;i<count;++i) {
            double v=silent ? 0 : double(src[ch][i]);
            if(std::isfinite(v)) peak=std::max(peak,std::abs(v));
            (ch==0 ? left : right)[i]=std::isfinite(v) ? float(std::max(-8.0,std::min(8.0,v))) : float(v);
        }
    }
    const uint64 mask=(uint64(1)<<out.numChannels)-1;
    out.silenceFlags=in.silenceFlags & mask;
    for(int32 ch=0;ch<out.numChannels;++ch) if(!src[ch]) out.silenceFlags|=uint64(1)<<ch;
    return std::min(1.0,peak);
}
tresult PLUGIN_API Processor::process(ProcessData& data) {
    if (data.numSamples < 0 || canProcessSampleSize(data.symbolicSampleSize) != kResultTrue) return kInvalidArgument;
    if (resetPending.exchange(false,std::memory_order_acq_rel)) { VHSInput reset{}; reset.kind=4; vhs_bridge_push(bridge,reset); vhs_audio_mark_gap(vhs_bridge_audio(bridge)); }
    const bool offline=data.processMode==kOffline;
    bool bypassed=vhs_bridge_get_bypass(bridge)!=0;
    if(data.processContext && data.processContext->projectTimeSamples!=sampleCursor) vhs_audio_mark_gap(vhs_bridge_audio(bridge));
    if(data.processContext) sampleCursor=data.processContext->projectTimeSamples;
    // Host parameter queues and event lists are bounded by the negotiated block and
    // a fixed inspection budget. Saturation resets notes through the overflow counter.
    if (auto* changes = data.inputParameterChanges) {
        const int32 queues=std::min(changes->getParameterCount(),int32(2309));
        int32 ccBudget=512;
        for(int32 q=0;q<queues;++q) {
            auto* queue=changes->getParameterData(q); if(!queue) continue;
            const auto id=queue->getParameterId();
            const bool automation=id>=VHS_AUTOMATION_FIRST && id<VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS;
            const bool cc=id>=0x1000 && id<0x1800;
            if(id>3 && !automation && id!=0x3000 && !cc) continue;
            const int32 points=queue->getPointCount();
            const int32 count=cc ? std::min(points,ccBudget) : std::min(points,int32(1));
            for(int32 i=0;i<count;++i) {
                int32 offset=0; ParamValue value=0;
                if(queue->getPoint(cc ? i : points-1,offset,value)!=kResultTrue || !std::isfinite(value) || value<0 || value>1 ||
                   offset<0 || offset>=std::max(data.numSamples,int32(1))) continue;
                if(automation) vhs_bridge_set_automation(bridge,id-VHS_AUTOMATION_FIRST,value);
                else if(id==0x3000) { bypassed=value>=0.5; vhs_bridge_set_bypass(bridge,bypassed); }
                else if(id<4) vhs_bridge_set(bridge,id,value);
                else {
                    VHSInput event{}; event.kind=3; event.offset=offset;
                    event.channel=(id-0x1000)/128; event.number=(id-0x1000)%128; event.value=value;
                    event.sampleTime=sampleCursor;
                    if(event.number==1) vhs_bridge_set(bridge,3,value);
                    if(event.number==120 || event.number>=123) vhs_bridge_set(bridge,3,0);
                    vhs_bridge_push(bridge,event);
                }
            }
            if(cc) {
                ccBudget-=count;
                if(points>count) { VHSInput reset{}; reset.kind=4; vhs_bridge_push(bridge,reset); }
            }
        }
    }
    if (auto* events=data.inputEvents) {
        const int32 count=std::min(events->getEventCount(),int32(512));
        for (int32 i=0; i<count; ++i) {
            Event e{}; if (events->getEvent(i,e)!=kResultTrue) continue;
            VHSInput v{}; v.offset=e.sampleOffset;
            if (e.type==Event::kNoteOnEvent) { v.kind=e.noteOn.velocity>0 ? 1:2; v.channel=e.noteOn.channel; v.number=e.noteOn.pitch; v.value=e.noteOn.velocity; }
            else if(e.type==Event::kNoteOffEvent) { v.kind=2; v.channel=e.noteOff.channel; v.number=e.noteOff.pitch; }
            else continue;
            if(v.channel<0 || v.channel>=16 || v.number<0 || v.number>=128 ||
               !std::isfinite(v.value) || v.value<0 || v.value>1 || v.offset<0 || v.offset>=std::max(data.numSamples,int32(1))) continue;
            if (data.processContext) v.sampleTime=data.processContext->projectTimeSamples;
            vhs_bridge_push(bridge,v);
        }
        if(events->getEventCount()>512) { VHSInput reset{}; reset.kind=4; vhs_bridge_push(bridge,reset); }
    }
    double peak=0;
    if(data.numSamples==0 || data.numInputs!=1 || data.numOutputs!=1 || !data.inputs || !data.outputs) vhs_audio_mark_gap(vhs_bridge_audio(bridge));
    if(data.numSamples>0 && data.numInputs==1 && data.numOutputs==1 && data.inputs && data.outputs) {
        auto& in=data.inputs[0]; auto& out=data.outputs[0];
        if((in.numChannels!=1 && in.numChannels!=2) || out.numChannels!=in.numChannels) return kResultFalse;
        if(data.symbolicSampleSize==kSample32 && in.channelBuffers32 && out.channelBuffers32) peak=pass(in,out,data.numSamples,in.channelBuffers32,out.channelBuffers32,analysisLeft.data(),analysisRight.data());
        else if(data.symbolicSampleSize==kSample64 && in.channelBuffers64 && out.channelBuffers64) peak=pass(in,out,data.numSamples,in.channelBuffers64,out.channelBuffers64,analysisLeft.data(),analysisRight.data());
        else return kResultFalse;
        if(!offline && !bypassed) vhs_audio_push_planar(vhs_bridge_audio(bridge),
            data.numSamples<=VHS_AUDIO_MAX_BLOCK ? analysisLeft.data() : nullptr,
            in.numChannels==2 ? analysisRight.data() : nullptr,uint32(data.numSamples),processSetup.sampleRate,sampleCursor);
    }
    if(offline || bypassed) {
        vhs_audio_mark_gap(vhs_bridge_audio(bridge)); VHSInput reset{}; reset.kind=4; vhs_bridge_push(bridge,reset); peak=0;
    }
    VHSHostContext context{}; context.sampleRate=processSetup.sampleRate;
    if(auto* c=data.processContext) {
        context.flags=1; context.samplePosition=c->projectTimeSamples;
        if(c->state & ProcessContext::kPlaying) context.flags|=2;
        if((c->state & ProcessContext::kTempoValid) && std::isfinite(c->tempo) && c->tempo>0) { context.flags|=4; context.tempo=c->tempo; }
        if((c->state & ProcessContext::kProjectTimeMusicValid) && std::isfinite(c->projectTimeMusic)) { context.flags|=8; context.beats=c->projectTimeMusic; }
    }
    if(offline || bypassed) context.flags|=16;
    vhs_bridge_host_context(bridge,context);
    if(sampleCursor<=INT64_MAX-data.numSamples) sampleCursor+=data.numSamples;
    VHSInput block{}; block.value=peak;
    if(auto* c=data.processContext) { block.flags=1; if(c->state & ProcessContext::kPlaying) block.flags|=2;
        if((c->state & ProcessContext::kTempoValid) && std::isfinite(c->tempo) && c->tempo>0) { block.flags|=4; block.tempo=c->tempo; } block.sampleTime=c->projectTimeSamples; }
    vhs_bridge_push(bridge,block);
    return kResultOk;
}
tresult PLUGIN_API Processor::getState(IBStream* stream) {
    if(!stream) return kInvalidArgument;
    std::array<uint8_t,VHS_STATE_CAPACITY> bytes{};
    const int count=vhs_bridge_copy_document(bridge,bytes.data(),VHS_STATE_CAPACITY,nullptr,nullptr);
    if(count<0) return kResultFalse;
    IBStreamer s(stream,kLittleEndian);
    if(!s.writeInt32(0x56485333)) return kResultFalse;
    for(uint32 i=0;i<3;++i) if(!s.writeDouble(vhs_bridge_get(bridge,i))) return kResultFalse;
    for(uint32 i=0;i<VHS_AUTOMATION_SLOTS;++i) if(!s.writeDouble(vhs_bridge_get_automation(bridge,i))) return kResultFalse;
    if(!s.writeDouble(getParamNormalized(0x3000))) return kResultFalse;
    if(!s.writeInt32(count) || (count && s.writeRaw(bytes.data(),count)!=count)) return kResultFalse;
    return kResultOk;
}
tresult PLUGIN_API Processor::setState(IBStream* stream) {
    if(!stream) return kInvalidArgument;
    IBStreamer s(stream,kLittleEndian); int32 magic=0; double values[3];
    if(!s.readInt32(magic) || (magic!=0x56485331 && magic!=0x56485332 && magic!=0x56485333)) return kResultFalse;
    for(auto& v:values) if(!s.readDouble(v) || !std::isfinite(v) || v<0 || v>1) return kResultFalse;
    std::array<double,VHS_AUTOMATION_SLOTS> automation{}; double bypass=0;
    if(magic==0x56485333) {
        for(auto& value:automation) if(!s.readDouble(value) || !std::isfinite(value) || value<0 || value>1) return kResultFalse;
        if(!s.readDouble(bypass) || !std::isfinite(bypass) || bypass<0 || bypass>1) return kResultFalse;
    }
    std::array<uint8_t,VHS_STATE_CAPACITY> bytes{}; int32 count=0;
    if(magic==0x56485332 || magic==0x56485333) {
        if(!s.readInt32(count) || count<0 || (magic==0x56485332 && count==0) || count>VHS_STATE_CAPACITY || s.readRaw(bytes.data(),count)!=count) return kResultFalse;
        // Pure bounded decoding/validation only; no view, disk, render or compiler.
        // process() never calls this function or enters Swift.
        if(count && !vhs_document_validate(bytes.data(),count)) return kResultFalse;
    }
    if(vhs_bridge_restore_state(bridge,bytes.data(),count,values,automation.data(),bypass>=0.5)<0) return kResultFalse;
    for(uint32 i=0;i<3;++i) setParamNormalized(i,values[i]);
    for(uint32 i=0;i<VHS_AUTOMATION_SLOTS;++i) setParamNormalized(VHS_AUTOMATION_FIRST+i,automation[i]);
    setParamNormalized(0x3000,bypass);
    resetPending=true;
    return kResultOk;
}
IPlugView* PLUGIN_API Processor::createView(FIDString name) {
    if(!name || std::strcmp(name,ViewType::kEditor) || ![NSThread isMainThread]) return nullptr;
    if(!runtime) {
        NSBundle* bundle=[NSBundle bundleForClass:[VHSProductionBundleMarker class]];
        NSBundle* resources=[NSBundle bundleWithPath:[[bundle resourcePath] stringByAppendingPathComponent:@"VHS_VHSRenderer.bundle"]];
        NSString* shader=[[resources resourcePath] stringByAppendingPathComponent:@"Shaders/Scene.metal"];
        if(!shader) return nullptr;
        runtime=vhs_ui_create(bridge,[shader fileSystemRepresentation]);
        if(!runtime) return nullptr;
        vhs_bridge_callback(bridge,this,[](void* context,uint32 id,double value,uint32 phase) {
            auto* self=static_cast<Processor*>(context);
            if(phase==3) {
                // Scene/preset loads keep the existing parameter IDs and update
                // host-visible values without manufacturing automation gestures.
                for(uint32 i=0;i<3;++i)
                    self->SingleComponentEffect::setParamNormalized(i,vhs_bridge_get(self->bridge,i));
                for(uint32 i=0;i<VHS_AUTOMATION_SLOTS;++i)
                    self->SingleComponentEffect::setParamNormalized(VHS_AUTOMATION_FIRST+i,vhs_bridge_get_automation(self->bridge,i));
                if(self->componentHandler) self->componentHandler->restartComponent(kParamValuesChanged);
                self->setDirty(true);
            }
            else if(phase==0) self->beginEdit(id);
            else if(phase==1) { self->setParamNormalized(id,value); self->performEdit(id,value); }
            else self->endEdit(id);
        });
    }
    return new Editor(this,runtime);
}
}
using namespace Steinberg;
using namespace Steinberg::Vst;
BEGIN_FACTORY_DEF("VHS", "", "")
DEF_CLASS2(INLINE_UID_FROM_FUID(VHS::productionID), PClassInfo::kManyInstances, kVstAudioEffectClass,
           "VHS", 0, "Fx|Analyzer", "0.8.0", kVstVersionString, VHS::Processor::create)
END_FACTORY
