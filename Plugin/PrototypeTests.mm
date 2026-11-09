#include "Prototype.h"
#include "public.sdk/source/vst/hosting/hostclasses.h"
#include "public.sdk/source/vst/hosting/eventlist.h"
#include "public.sdk/source/vst/hosting/parameterchanges.h"
#include "public.sdk/source/common/memorystream.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"
#include <cassert>
#include <cstring>
#include <cstdio>
#include <limits>
using namespace VHS;
int main() {
    HostApplication host;
    auto* p=new Prototype;
    assert(p->initialize(&host)==kResultOk);
    auto* second=new Prototype;
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
    double dl[4]={-.4,1,.123,0}, dr[4]={1,-1,.9,0}, dol[4]{},dor[4]{}; double* dins[2]={dl,dr}; double* douts[2]={dol,dor};
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
    assert(p->terminate()==kResultOk); assert(second->terminate()==kResultOk); p->release(); second->release();
    puts("PASS real processor: stereo float/double, byte equality/NaN, in-place, silence, zero block, note offsets, transport, CC1, instance isolation, transactional state");
}
