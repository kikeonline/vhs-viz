#pragma once
#include "public.sdk/source/vst/vstsinglecomponenteffect.h"
#include "pluginterfaces/vst/ivstmidicontrollers.h"
#include "VHSRealtime.h"
namespace VHS {
using namespace Steinberg;
using namespace Steinberg::Vst;
inline const FUID prototypeID(0x80722923, 0x863C4290, 0xA50F11B8, 0x071A3A01);
class Prototype final : public SingleComponentEffect, public IMidiMapping {
public:
    Prototype();
    ~Prototype() override;
    static FUnknown* create(void*) { return static_cast<IAudioProcessor*>(new Prototype); }
    tresult PLUGIN_API initialize(FUnknown*) override;
    tresult PLUGIN_API terminate() override;
    tresult PLUGIN_API process(ProcessData&) override;
    tresult PLUGIN_API setProcessing(TBool) override;
    tresult PLUGIN_API canProcessSampleSize(int32) override;
    tresult PLUGIN_API setBusArrangements(SpeakerArrangement*, int32, SpeakerArrangement*, int32) override;
    tresult PLUGIN_API setState(IBStream*) override;
    tresult PLUGIN_API getState(IBStream*) override;
    tresult PLUGIN_API setParamNormalized(ParamID, ParamValue) override;
    ParamValue PLUGIN_API getParamNormalized(ParamID id) override { return id<4 ? vhs_bridge_get(bridge,id) : 0; }
    tresult PLUGIN_API getMidiControllerAssignment(int32, int16, CtrlNumber, ParamID&) override;
    IPlugView* PLUGIN_API createView(FIDString) override;
    tresult PLUGIN_API queryInterface(const TUID, void**) override;
    REFCOUNT_METHODS(SingleComponentEffect)
    VHSBridge* bridge;
private:
    void* runtime = nullptr;
    bool resetPending = true;
};
}
