#include "Processor.h"
#include "public.sdk/source/vst/hosting/hostclasses.h"
#include "public.sdk/source/vst/hosting/eventlist.h"
#include "public.sdk/source/vst/hosting/parameterchanges.h"
#include "public.sdk/source/common/memorystream.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"
#include <cassert>
#include <cstring>
#include <cstdio>
#include <limits>
#include <fstream>
#include <vector>
#include <cmath>
#include <thread>
#include "base/source/fstreamer.h"
using namespace VHS;
int main(int argc,char** argv) {
    HostApplication host;
    auto* p=new Processor;
    assert(p->initialize(&host)==kResultOk);
    auto* second=new Processor;
    assert(second->initialize(&host)==kResultOk);
    ProcessSetup setup{}; setup.sampleRate=48000; setup.maxSamplesPerBlock=16; setup.symbolicSampleSize=kSample32;
    assert(p->setupProcessing(setup)==kResultOk);
    float left[4]={-.5f,0,.25f,std::numeric_limits<float>::quiet_NaN()}, right[4]={1,-1,0,.125f};
    float lo[4]{},ro[4]{}; float* ins[2]={left,right}; float* outs[2]={lo,ro};
    AudioBusBuffers in{},out{}; in.numChannels=out.numChannels=2; in.channelBuffers32=ins; out.channelBuffers32=outs;
    ProcessData d{}; d.numSamples=4; d.numInputs=d.numOutputs=1; d.inputs=&in; d.outputs=&out; d.symbolicSampleSize=kSample32;
    ProcessContext context{}; context.state=ProcessContext::kPlaying|ProcessContext::kTempoValid; context.tempo=137; context.projectTimeSamples=98765;
    d.processContext=&context;
    EventList events; Event note{}; note.type=Event::kNoteOnEvent; note.sampleOffset=2; note.noteOn.channel=2; note.noteOn.pitch=60; note.noteOn.velocity=.75f; events.addEvent(note); d.inputEvents=&events;
    ParameterChanges changes(4); int32 index=0; auto* q=changes.addParameterData(3,index); q->addPoint(3,.6,index);
    auto* cc74=changes.addParameterData(0x124a,index); cc74->addPoint(1,.5,index);
    d.inputParameterChanges=&changes;
    assert(p->process(d)==kResultOk);
    assert(!std::memcmp(left,lo,sizeof(left)) && !std::memcmp(right,ro,sizeof(right)));
    assert(vhs_bridge_get(p->bridge,3)==.6 && vhs_bridge_get(second->bridge,3)==0);
    VHSInput event{}; bool foundNote=false,foundBlock=false,foundCC=false;
    while(vhs_bridge_pop(p->bridge,&event)) {
        if(event.kind==1) { foundNote=true; assert(event.offset==2 && event.sampleTime==98765 && event.channel==2 && event.value==.75); }
        if(event.kind==3 && event.number==74) { foundCC=true; assert(event.channel==4 && event.offset==1 && event.sampleTime==98765 && event.value==.5); }
        if(event.kind==0) { foundBlock=true; assert(event.tempo==137 && event.flags==7 && event.value==1); }
    }
    assert(foundNote && foundBlock && foundCC);
    d.inputEvents=nullptr; d.inputParameterChanges=nullptr;
    out.channelBuffers32=ins; assert(p->process(d)==kResultOk); assert(left[0]==-.5f && right[0]==1);
    out.channelBuffers32=outs; in.silenceFlags=3; assert(p->process(d)==kResultOk); assert(lo[0]==0 && ro[0]==0 && out.silenceFlags==3);
    double dl[4]={-.4,1,std::numeric_limits<double>::quiet_NaN(),0}, dr[4]={1,-1,.9,-0.0}, dol[4]{},dor[4]{}; double* dins[2]={dl,dr}; double* douts[2]={dol,dor};
    in.silenceFlags=0; in.channelBuffers64=dins; out.channelBuffers64=douts; d.symbolicSampleSize=kSample64;
    assert(p->process(d)==kResultOk); assert(!std::memcmp(dl,dol,sizeof(dl)) && !std::memcmp(dr,dor,sizeof(dr)));
    d.numSamples=0; d.numInputs=d.numOutputs=0; d.inputs=d.outputs=nullptr; assert(p->process(d)==kResultOk);
    ParamID id=0; assert(p->getMidiControllerAssignment(0,15,1,id)==kResultTrue && id==0x1781);
    assert(p->getMidiControllerAssignment(0,0,74,id)==kResultTrue && id==0x104a);
    assert(p->getMidiControllerAssignment(1,0,7,id)==kResultFalse);
    assert(p->setParamNormalized(0,.83)==kResultOk);
    MemoryStream saved; assert(p->getState(&saved)==kResultOk); saved.seek(0,IBStream::kIBSeekSet,nullptr);
    assert(second->setState(&saved)==kResultOk); assert(vhs_bridge_get(second->bridge,0)==.83);
    MemoryStream broken(saved.getData(),saved.getSize()-1); assert(second->setState(&broken)!=kResultOk); assert(vhs_bridge_get(second->bridge,0)==.83);
    assert(argc==2);
    std::ifstream file(argv[1],std::ios::binary);
    std::vector<uint8_t> graph((std::istreambuf_iterator<char>(file)),std::istreambuf_iterator<char>());
    assert(!graph.empty() && graph.size()<VHS_STATE_CAPACITY);
    assert(vhs_bridge_store_document(p->bridge,graph.data(),uint32_t(graph.size()),0)==int(graph.size()));
    MemoryStream extended; assert(p->getState(&extended)==kResultOk); extended.seek(0,IBStream::kIBSeekSet,nullptr);
    assert(second->setState(&extended)==kResultOk);
    std::vector<uint8_t> restored(VHS_STATE_CAPACITY); uint32_t origin=0,revision=0;
    assert(vhs_bridge_copy_document(second->bridge,restored.data(),VHS_STATE_CAPACITY,&origin,&revision)==int(graph.size()));
    assert(origin==1 && !std::memcmp(restored.data(),graph.data(),graph.size()));
    MemoryStream cut(extended.getData(),extended.getSize()-1);
    assert(second->setState(&cut)!=kResultOk && vhs_bridge_document_revision(second->bridge)==revision);
    MemoryStream malformed; IBStreamer bad(&malformed,kLittleEndian);
    bad.writeInt32(0x56485332); for(int i=0;i<3;++i) bad.writeDouble(.5); bad.writeInt32(2); bad.writeRaw("{}",2);
    malformed.seek(0,IBStream::kIBSeekSet,nullptr);
    assert(second->setState(&malformed)!=kResultOk && vhs_bridge_document_revision(second->bridge)==revision);
    // Fixed slots are exposed at stable IDs and survive state without an editor.
    assert(p->getParameterCount()==2309);
    assert(p->setParamNormalized(VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS,.5)==kInvalidArgument);
    assert(p->setParamNormalized(VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS-1,.73)==kResultOk);
    assert(p->getParamNormalized(VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS-1)==.73);
    MemoryStream slotsState; assert(p->getState(&slotsState)==kResultOk);
    slotsState.seek(0,IBStream::kIBSeekSet,nullptr);
    assert(second->setState(&slotsState)==kResultOk && second->getParamNormalized(VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS-1)==.73);
    MemoryStream truncatedSlots(slotsState.getData(),slotsState.getSize()-3);
    assert(second->setState(&truncatedSlots)!=kResultOk && second->getParamNormalized(VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS-1)==.73);

    SpeakerArrangement mono=SpeakerArr::kMono, stereo=SpeakerArr::kStereo;
    assert(p->setBusArrangements(&mono,1,&mono,1)==kResultOk);
    assert(p->setBusArrangements(&mono,1,&stereo,1)==kResultFalse);
    setup.sampleRate=96000; setup.maxSamplesPerBlock=4096; setup.symbolicSampleSize=kSample32;
    assert(p->setupProcessing(setup)==kResultOk);
    std::vector<float> tone(4096), monoOut(4096);
    for(int i=0;i<4096;++i) tone[i]=float(.5*std::sin(2*3.141592653589793*100*i/96000));
    float* monoInChannels[]={tone.data()}; float* monoOutChannels[]={monoOut.data()};
    in.numChannels=out.numChannels=1; in.channelBuffers32=monoInChannels; out.channelBuffers32=monoOutChannels;
    d.numInputs=d.numOutputs=1; d.inputs=&in; d.outputs=&out; d.symbolicSampleSize=kSample32; d.numSamples=4096;
    context.state=ProcessContext::kPlaying|ProcessContext::kTempoValid|ProcessContext::kProjectTimeMusicValid;
    context.projectTimeSamples=0; context.projectTimeMusic=12.5; context.tempo=120; d.processContext=&context;
    assert(p->process(d)==kResultOk && !std::memcmp(tone.data(),monoOut.data(),tone.size()*sizeof(float)));
    VHSAudioChunk chunk{}; int frames=0;
    const auto generation=vhs_audio_generation(vhs_bridge_audio(p->bridge));
    while(vhs_audio_pop(vhs_bridge_audio(p->bridge),&chunk)) if(chunk.generation==generation) {
        assert(chunk.channels==1 && chunk.sampleRate==96000);
        for(unsigned i=0;i<chunk.frames;++i) assert(chunk.samples[i]==tone[frames+i]);
        frames+=chunk.frames;
    }
    assert(frames==4096);
    VHSHostContext hostContext{}; uint32_t contextRevision=0;
    assert(vhs_bridge_copy_host_context(p->bridge,&hostContext,&contextRevision));
    assert(hostContext.beats==12.5 && hostContext.tempo==120 && hostContext.flags==15);
    assert(p->getLatencySamples()==0);
    VHSInput discarded{}; while(vhs_bridge_pop(p->bridge,&discarded)) {}
    ParameterChanges timedCC(4); auto* ccSeries=timedCC.addParameterData(0x104a,index);
    ccSeries->addPoint(1,.1,index); ccSeries->addPoint(9,.4,index); ccSeries->addPoint(23,.8,index);
    d.inputParameterChanges=&timedCC;
    assert(p->process(d)==kResultOk);
    int timedCount=0; const int expectedOffsets[]={1,9,23};
    while(vhs_bridge_pop(p->bridge,&discarded)) if(discarded.kind==3 && discarded.number==74) {
        assert(timedCount<3 && discarded.offset==expectedOffsets[timedCount]); ++timedCount;
    }
    assert(timedCount==3);
    // Endpoint automation works in process() with no Swift runtime/editor.
    ParameterChanges visualChanges(4); auto* visualQueue=visualChanges.addParameterData(VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS-1,index);
    visualQueue->addPoint(17,.91,index); d.inputParameterChanges=&visualChanges;
    context.projectTimeSamples=4096;
    assert(p->process(d)==kResultOk && p->getParamNormalized(VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS-1)==.91);
    d.inputParameterChanges=nullptr;
    assert(p->setParamNormalized(0x3000,1)==kResultOk);
    auto beforeBypass=vhs_audio_generation(vhs_bridge_audio(p->bridge));
    assert(p->process(d)==kResultOk && vhs_audio_generation(vhs_bridge_audio(p->bridge))!=beforeBypass);
    assert(!std::memcmp(tone.data(),monoOut.data(),tone.size()*sizeof(float)));
    MemoryStream bypassState; assert(p->getState(&bypassState)==kResultOk); bypassState.seek(0,IBStream::kIBSeekSet,nullptr);
    assert(second->setState(&bypassState)==kResultOk && second->getParamNormalized(0x3000)==1);
    assert(p->setParamNormalized(0x3000,0)==kResultOk);
    d.processMode=kOffline;
    assert(p->process(d)==kResultOk && !std::memcmp(tone.data(),monoOut.data(),tone.size()*sizeof(float)));
    assert(vhs_bridge_copy_host_context(p->bridge,&hostContext,nullptr) && (hostContext.flags&16));
    d.processMode=kRealtime;
    assert(p->setActive(false)==kResultOk && p->setActive(true)==kResultOk);
    assert(p->setProcessing(false)==kResultOk && p->setProcessing(true)==kResultOk);
    // State callbacks run on the control thread while process remains C++/C only.
    d.inputParameterChanges=nullptr; d.inputEvents=nullptr;
    std::thread audioThread([&] { for(int i=0;i<2000;++i) assert(p->process(d)==kResultOk); });
    for(int i=0;i<40;++i) {
        slotsState.seek(0,IBStream::kIBSeekSet,nullptr);
        assert(p->setState(&slotsState)==kResultOk);
        MemoryStream concurrent; assert(p->getState(&concurrent)==kResultOk);
    }
    audioThread.join();
    puts("PASS concurrent state: 40 validated restores/snapshots during 2000 process blocks without an editor");
    // Legacy RGB state remains a transactional migration input under the new class ID.
    MemoryStream legacy; IBStreamer legacyWriter(&legacy,kLittleEndian);
    legacyWriter.writeInt32(0x56485331); for(int i=0;i<3;++i) legacyWriter.writeDouble(.42);
    legacy.seek(0,IBStream::kIBSeekSet,nullptr);
    assert(second->setState(&legacy)==kResultOk && second->getParamNormalized(0)==.42);
    assert(second->getParamNormalized(VHS_AUTOMATION_FIRST+VHS_AUTOMATION_SLOTS-1)==0 && second->getParamNormalized(0x3000)==0);
    puts("PASS production host: fixed slots/editor-closed automation/state, mono 96 kHz analysis sample parity, musical context, bypass/offline transparency, legacy migration");
    puts("PASS graph state: embedded topology/parameters/seed/layout, before-editor restore, truncated/malformed rejection preserves prior state");
    assert(p->terminate()==kResultOk); assert(second->terminate()==kResultOk); p->release(); second->release();
    puts("PASS real processor: stereo float/double, byte equality/NaN, in-place, silence, zero block, note offsets, transport, CC1, instance isolation, transactional state");
}
