#pragma once
#include "public.sdk/source/vst/vstsinglecomponenteffect.h"
#include "pluginterfaces/vst/ivstmidicontrollers.h"
#include "VHSRealtime.h"
#include <array>
#include <atomic>
namespace VHS {
using namespace Steinberg;
using namespace Steinberg::Vst;
inline const FUID productionID(0xB5A87F12, 0x0EC54856, 0xA624B9EE, 0x6C820001);
class Processor final : public SingleComponentEffect, public IMidiMapping {
public:
    Processor();
    ~Processor() override;
    static FUnknown* create(void*) { return static_cast<IAudioProcessor*>(new Processor); }
    tresult PLUGIN_API initialize(FUnknown*) override;
    tresult PLUGIN_API terminate() override;
    tresult PLUGIN_API process(ProcessData&) override;
    tresult PLUGIN_API setProcessing(TBool) override;
    tresult PLUGIN_API setActive(TBool) override;
    tresult PLUGIN_API canProcessSampleSize(int32) override;
    tresult PLUGIN_API setBusArrangements(SpeakerArrangement*, int32, SpeakerArrangement*, int32) override;
    tresult PLUGIN_API setState(IBStream*) override;
    tresult PLUGIN_API getState(IBStream*) override;
    tresult PLUGIN_API setParamNormalized(ParamID, ParamValue) override;
    ParamValue PLUGIN_API getParamNormalized(ParamID id) override;
    tresult PLUGIN_API setupProcessing(ProcessSetup&) override;
    tresult PLUGIN_API getMidiControllerAssignment(int32, int16, CtrlNumber, ParamID&) override;
    IPlugView* PLUGIN_API createView(FIDString) override;
    tresult PLUGIN_API queryInterface(const TUID, void**) override;
    uint32 PLUGIN_API addRef() override { return SingleComponentEffect::addRef(); }
    uint32 PLUGIN_API release() override;
    VHSBridge* bridge;
private:
    void* runtime = nullptr;
    std::atomic<bool> resetPending{true};
    int64 sampleCursor = 0;
    std::array<float,VHS_AUDIO_MAX_BLOCK> analysisLeft{}, analysisRight{};
};
}
