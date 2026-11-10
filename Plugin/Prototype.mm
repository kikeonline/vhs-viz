#include "Prototype.h"
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

@interface VHSBundleMarker : NSObject @end
@implementation VHSBundleMarker @end
extern "C" int vhs_document_validate(const uint8_t*, uint32_t);
extern "C" void* vhs_ui_create(VHSBridge*, const char*);
extern "C" void* vhs_ui_attach(void*, void*);
extern "C" void vhs_ui_detach(void*);
extern "C" void vhs_ui_destroy(void*);
namespace VHS {
class Editor final : public CPluginView {
    IPtr<Prototype> owner;
    void* runtime;
    void* view = nullptr;
public:
    Editor(Prototype* owner, void* runtime): owner(owner), runtime(runtime) { rect = {0,0,1000,720}; }
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
Prototype::Prototype(): bridge(vhs_bridge_create()) {
    processContextRequirements.needTempo().needTransportState().needSystemTime();
}
Prototype::~Prototype() {
    if (bridge) {
        vhs_bridge_callback(bridge, nullptr, nullptr);
        if (runtime) vhs_ui_destroy(runtime);
        vhs_bridge_release(bridge);
    }
}
tresult PLUGIN_API Prototype::initialize(FUnknown* context) {
    if (!bridge) return kOutOfMemory;
    auto result = SingleComponentEffect::initialize(context);
    if (result != kResultOk) return result;
    addAudioInput(STR16("Stereo In"), SpeakerArr::kStereo);
    addAudioOutput(STR16("Stereo Out"), SpeakerArr::kStereo);
    addEventInput(STR16("Visual MIDI"), 16);
    parameters.addParameter(STR16("Solid Red"), nullptr, 0, .24, ParameterInfo::kCanAutomate, 0);
    parameters.addParameter(STR16("Solid Green"), nullptr, 0, .08, ParameterInfo::kCanAutomate, 1);
    parameters.addParameter(STR16("Solid Blue"), nullptr, 0, .62, ParameterInfo::kCanAutomate, 2);
    parameters.addParameter(STR16("Visual CC1"), nullptr, 0, 0, ParameterInfo::kCanAutomate, 3);
    // A fixed probe-only discovery bank lets the host translate unassigned CCs
    // without relying on raw MIDI CC bytes in IEventList. Never renumber it.
    for(int ch=0;ch<16;++ch) for(int cc=0;cc<128;++cc) {
        String128 title{};
        char text[64]; std::snprintf(text,sizeof(text),"MIDI %d CC%d",ch+1,cc);
        UString(title,128).fromAscii(text);
        parameters.addParameter(title,nullptr,0,0,ParameterInfo::kIsHidden,0x1000+ch*128+cc);
    }
    return kResultOk;
}
tresult PLUGIN_API Prototype::terminate() {
    vhs_bridge_callback(bridge, nullptr, nullptr);
    if (runtime) { vhs_ui_destroy(runtime); runtime = nullptr; }
    return SingleComponentEffect::terminate();
}
tresult PLUGIN_API Prototype::queryInterface(const TUID iid, void** obj) {
    QUERY_INTERFACE(iid, obj, IMidiMapping::iid, IMidiMapping)
    return SingleComponentEffect::queryInterface(iid, obj);
}
tresult PLUGIN_API Prototype::getMidiControllerAssignment(int32 bus, int16 channel, CtrlNumber cc, ParamID& id) {
    if (bus == 0 && channel >= 0 && channel < 16 && cc >= 0 && cc < 128) { id=0x1000+channel*128+cc; return kResultTrue; }
    return kResultFalse;
}
tresult PLUGIN_API Prototype::setParamNormalized(ParamID id, ParamValue value) {
    if (!std::isfinite(value) || value < 0 || value > 1) return kInvalidArgument;
    if(id>=0x1000 && id<0x1800) return SingleComponentEffect::setParamNormalized(id,value);
    if(id>3) return kInvalidArgument;
    vhs_bridge_set(bridge, id, value);
    return SingleComponentEffect::setParamNormalized(id, value);
}
tresult PLUGIN_API Prototype::canProcessSampleSize(int32 size) { return size == kSample32 || size == kSample64 ? kResultTrue : kResultFalse; }
tresult PLUGIN_API Prototype::setBusArrangements(SpeakerArrangement* ins, int32 ni, SpeakerArrangement* outs, int32 no) {
    if (ni != 1 || no != 1 || !ins || !outs || ins[0] != SpeakerArr::kStereo || outs[0] != SpeakerArr::kStereo) return kResultFalse;
    return SingleComponentEffect::setBusArrangements(ins,ni,outs,no);
}
tresult PLUGIN_API Prototype::setProcessing(TBool) { resetPending = true; return kResultOk; }
// Copies bytes exactly (including NaN payloads), both precisions, including in-place buffers.
template<class Sample> double pass(AudioBusBuffers& in, AudioBusBuffers& out, int32 count, Sample** src, Sample** dst) {
    double peak = 0;
    for (int32 ch=0; ch<2; ++ch) {
        if (!dst[ch]) continue;
        const bool silent = (in.silenceFlags & (uint64(1) << ch)) != 0;
        if (!src[ch] || silent) { std::memset(dst[ch], 0, size_t(count)*sizeof(Sample)); continue; }
        if (src[ch] != dst[ch]) std::memmove(dst[ch], src[ch], size_t(count)*sizeof(Sample));
        for (int32 i=0; i<count; ++i) { double v=std::abs(double(src[ch][i])); if (std::isfinite(v)) peak=std::max(peak,v); }
    }
    out.silenceFlags = in.silenceFlags & 3;
    return std::min(1.0, peak);
}
tresult PLUGIN_API Prototype::process(ProcessData& data) {
    if (data.numSamples < 0 || canProcessSampleSize(data.symbolicSampleSize) != kResultTrue) return kInvalidArgument;
    if (resetPending) { VHSInput reset{}; reset.kind=4; vhs_bridge_push(bridge,reset); resetPending=false; }
    // Host parameter queues and event lists are bounded by the negotiated block and
    // a fixed inspection budget. Saturation resets notes through the overflow counter.
    if (auto* changes = data.inputParameterChanges) {
        const int32 queues = std::min(changes->getParameterCount(), int32(2052));
        for (int32 q=0; q<queues; ++q) {
            auto* queue=changes->getParameterData(q); if (!queue) continue;
            auto id=queue->getParameterId();
            if(id>3 && (id<0x1000 || id>=0x1800)) continue;
            int32 offset=0; ParamValue value=0;
            if (queue->getPointCount()>0 && queue->getPoint(queue->getPointCount()-1,offset,value)==kResultTrue &&
                std::isfinite(value) && value>=0 && value<=1) {
                if(id<4) vhs_bridge_set(bridge,id,value);
                else {
                    VHSInput event{}; event.kind=3; event.offset=offset;
                    event.channel=(id-0x1000)/128; event.number=(id-0x1000)%128; event.value=value;
                    if(data.processContext) event.sampleTime=data.processContext->projectTimeSamples;
                    if(event.number==1) vhs_bridge_set(bridge,3,value);
                    if(event.number==120 || event.number==123) { event.kind=4; vhs_bridge_set(bridge,3,0); }
                    vhs_bridge_push(bridge,event);
                }
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
               !std::isfinite(v.value) || v.value<0 || v.value>1 || v.offset<0) continue;
            if (data.processContext) v.sampleTime=data.processContext->projectTimeSamples;
            vhs_bridge_push(bridge,v);
        }
        if(events->getEventCount()>512) { VHSInput reset{}; reset.kind=4; vhs_bridge_push(bridge,reset); }
    }
    double peak=0;
    if(data.numSamples>0 && data.numInputs==1 && data.numOutputs==1 && data.inputs && data.outputs) {
        auto& in=data.inputs[0]; auto& out=data.outputs[0];
        if(in.numChannels!=2 || out.numChannels!=2) return kResultFalse;
        if(data.symbolicSampleSize==kSample32 && in.channelBuffers32 && out.channelBuffers32) peak=pass(in,out,data.numSamples,in.channelBuffers32,out.channelBuffers32);
        else if(data.symbolicSampleSize==kSample64 && in.channelBuffers64 && out.channelBuffers64) peak=pass(in,out,data.numSamples,in.channelBuffers64,out.channelBuffers64);
        else return kResultFalse;
    }
    VHSInput block{}; block.value=peak;
    if(auto* c=data.processContext) { block.flags=1; if(c->state & ProcessContext::kPlaying) block.flags|=2;
        if(c->state & ProcessContext::kTempoValid) { block.flags|=4; block.tempo=c->tempo; } block.sampleTime=c->projectTimeSamples; }
    vhs_bridge_push(bridge,block);
    return kResultOk;
}
tresult PLUGIN_API Prototype::getState(IBStream* stream) {
    if(!stream) return kInvalidArgument;
    std::array<uint8_t,VHS_STATE_CAPACITY> bytes{};
    const int count=vhs_bridge_copy_document(bridge,bytes.data(),VHS_STATE_CAPACITY,nullptr,nullptr);
    if(count<0) return kResultFalse;
    IBStreamer s(stream,kLittleEndian);
    // Legacy RGB-only states remain readable. Extended states embed a bounded,
    // versioned project; no external path or live input/window state is stored.
    if(!s.writeInt32(count ? 0x56485332 : 0x56485331)) return kResultFalse;
    for(uint32 i=0;i<3;++i) if(!s.writeDouble(vhs_bridge_get(bridge,i))) return kResultFalse;
    if(count && (!s.writeInt32(count) || s.writeRaw(bytes.data(),count)!=count)) return kResultFalse;
    return kResultOk;
}
tresult PLUGIN_API Prototype::setState(IBStream* stream) {
    if(!stream) return kInvalidArgument;
    IBStreamer s(stream,kLittleEndian); int32 magic=0; double values[3];
    if(!s.readInt32(magic) || (magic!=0x56485331 && magic!=0x56485332)) return kResultFalse;
    for(auto& v:values) if(!s.readDouble(v) || !std::isfinite(v) || v<0 || v>1) return kResultFalse;
    std::array<uint8_t,VHS_STATE_CAPACITY> bytes{}; int32 count=0;
    if(magic==0x56485332) {
        if(!s.readInt32(count) || count<=0 || count>VHS_STATE_CAPACITY || s.readRaw(bytes.data(),count)!=count) return kResultFalse;
        // Pure bounded decoding/validation only; no view, disk, render or compiler.
        // process() never calls this function or enters Swift.
        if(!vhs_document_validate(bytes.data(),count)) return kResultFalse;
    }
    if(vhs_bridge_store_document(bridge,bytes.data(),count,1)<0) return kResultFalse;
    for(uint32 i=0;i<3;++i) vhs_bridge_set(bridge,i,values[i]);
    return kResultOk;
}
IPlugView* PLUGIN_API Prototype::createView(FIDString name) {
    if(!name || std::strcmp(name,ViewType::kEditor) || ![NSThread isMainThread]) return nullptr;
    if(!runtime) {
        NSBundle* bundle=[NSBundle bundleForClass:[VHSBundleMarker class]];
        NSBundle* resources=[NSBundle bundleWithPath:[[bundle resourcePath] stringByAppendingPathComponent:@"VHS_VHSRenderer.bundle"]];
        NSString* shader=[[resources resourcePath] stringByAppendingPathComponent:@"Shaders/Scene.metal"];
        if(!shader) return nullptr;
        runtime=vhs_ui_create(bridge,[shader fileSystemRepresentation]);
        if(!runtime) return nullptr;
        vhs_bridge_callback(bridge,this,[](void* context,uint32 id,double value,uint32 phase) {
            auto* self=static_cast<Prototype*>(context);
            if(phase==3) self->setDirty(true);
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
DEF_CLASS2(INLINE_UID_FROM_FUID(VHS::prototypeID), PClassInfo::kManyInstances, kVstAudioEffectClass,
           "VHS Phase 3A", 0, "Fx|Analyzer", "0.4.1", kVstVersionString, VHS::Prototype::create)
END_FACTORY
