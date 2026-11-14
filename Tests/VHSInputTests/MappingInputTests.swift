import Testing
import VHSCore
@testable import VHSInput

@Test func hostNormalizedAndByteStreamMIDIProduceIdenticalMappingsAndReset() throws {
    let bytes: [UInt8] = [0x92,60,100,72,80,0xB2,74,64,0x92,72,0]
    var decoder = MIDIDecoder(), device = MIDIState(), host = MIDIState()
    for byte in bytes { if let e = decoder.accept(byte,sampleTime:0,offset:0) { device.apply(e) } }
    for e: MIDIEvent in [.init(kind:.noteOn,channel:3,number:60,value:100.0/127),.init(kind:.noteOn,channel:3,number:72,value:80.0/127),.init(kind:.controller,channel:3,number:74,value:64.0/127),.init(kind:.noteOff,channel:3,number:72,value:0)] { host.apply(e) }
    for source in [MappingSource.note,.velocity,.gate,.cc] {
        var m = VisualMapping(target:.init(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)); m.source = source; m.number = source == .cc ? 74 : nil
        #expect(device.mappingInputs().value(for:m) == host.mappingInputs().value(for:m))
    }
    var m = VisualMapping(target:.init(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)); m.source = .gate
    #expect(device.mappingInputs().value(for:m) == 1)
    device.apply(.init(kind:.controller,channel:3,number:123,value:0))
    #expect(device.mappingInputs().value(for:m) == nil)
    m.source = .cc; m.number = 74
    device.reset(); #expect(device.mappingInputs().value(for:m) == nil)
    host.apply(.init(kind:.controller,channel:3,number:121,value:0))
    #expect(host.mappingInputs().value(for:m) == nil)
    try host.selectChannel(2)
    host.apply(.init(kind:.noteOn,channel:3,number:60,value:1))
    m.source = .gate; m.number = nil
    #expect(host.mappingInputs().value(for:m) == nil)
}
@Test func sharedAudioSignalsMapEveryAnalysisFeature() {
    var audio = AudioSignals(); audio.ready = true
    audio.rms = 0.1; audio.peak = 0.2; audio.low = 0.3; audio.mid = 0.4; audio.high = 0.5; audio.transient = 0.6
    let input = MIDIState().mappingInputs(audio:audio,available:false)
    for (source,value) in [(MappingSource.rms,0.1),(.peak,0.2),(.low,0.3),(.mid,0.4),(.high,0.5),(.transient,0.6)] {
        var m = VisualMapping(target:.init(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)); m.source = source
        #expect(input.value(for:m) == value)
    }
    #expect(MIDIState().mappingInputs(audio:AudioSignals()).audio.isEmpty)
}
