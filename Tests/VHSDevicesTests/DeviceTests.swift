import Testing
import Foundation
import CoreMIDI
import VHSDevices
import VHSDeviceIO
import VHSRealtime
import VHSInput

@Suite(.serialized) struct DeviceTests {
    @Test func selectionSurvivesEndpointChangesWithoutSubstitution() {
        let channels = AudioChannels(left: 1, right: 2)
        let original = AudioDevice(id: "interface-A", name: "Interface", objectID: 10, channels: 4, sampleRate: 48_000)
        let replacement = AudioDevice(id: "interface-A", name: "Interface", objectID: 99, channels: 4, sampleRate: 96_000)
        let unrelated = AudioDevice(id: "interface-B", name: "Interface", objectID: 11, channels: 4, sampleRate: 48_000)
        #expect(InputResolution.audio(id: original.id, channels: channels, devices: [unrelated]) == nil)
        #expect(InputResolution.audio(id: original.id, channels: channels, devices: [replacement]) == replacement)
        #expect(InputResolution.audio(id: original.id, channels: channels, devices: [original, replacement]) == nil)
        let source = MIDISource(id: 1234, name: "Controller", endpoint: 100)
        #expect(InputResolution.midi(id: 1234, sources: [source]) == source)
        #expect(InputResolution.midi(id: 5678, sources: [source]) == nil)
        #expect(InputResolution.midi(id: 1234, sources: [source, source]) == nil)
    }
    @Test func channelChoicesRejectMissingAndDuplicateChannels() {
        #expect(AudioChannels.choices(count: 0).isEmpty)
        #expect(AudioChannels.choices(count: 1) == [AudioChannels(left: 0)])
        #expect(AudioChannels.choices(count: 4).count == 7)
        for choice in AudioChannels.choices(count: 4) { #expect(choice.isValid(for: 4)) }
        #expect(!AudioChannels(left: -1).isValid(for: 2))
        #expect(!AudioChannels(left: 0, right: 0).isValid(for: 2))
        #expect(!AudioChannels(left: 1, right: 2).isValid(for: 2))
        #expect(AudioChannels.choices(count: 10_000).count == 511)
    }
    @Test func nativeAudioEnqueueMatchesSharedPlanarContractAndRejectsBadTime() throws {
        let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
        let referenceQueue = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(referenceQueue) }
        let analyzer = try AudioAnalyzer()
        let reference = try AudioAnalyzer()
        let left = (0..<2048).map { Float(0.5 * sin(2 * Double.pi * 32 * Double($0) / 2048)) }
        let right = left.map { -$0 }
        #expect(left.withUnsafeBufferPointer { l in right.withUnsafeBufferPointer { r in
            vhs_device_audio_enqueue(q, l.baseAddress, r.baseAddress, 2048, 48_000, 100)
        } } == 1)
        try analyzer.drain(q)
        let interleaved = zip(left, right).flatMap { [$0.0, $0.1] }
        #expect(interleaved.withUnsafeBufferPointer { vhs_audio_push_interleaved(referenceQueue, $0.baseAddress, 2048, 2, 48_000, 100) } == 1)
        try reference.drain(referenceQueue)
        #expect(analyzer.signals == reference.signals)
        #expect(abs(analyzer.signals.rms - 0.5 / sqrt(2)) < 0.00001)
        #expect(analyzer.signals.endSampleTime == 2148)
        for time in [Double.nan, .infinity, 1.5, pow(2.0, 63)] {
            #expect(left.withUnsafeBufferPointer { vhs_device_audio_enqueue(q, $0.baseAddress, nil, 1, 48_000, time) } == 0)
        }
        try analyzer.drain(q)
        #expect(!analyzer.signals.ready)
    }
    @Test func invalidNativeStartsFailWithoutOpeningHardware() throws {
        let a = try #require(vhs_audio_queue_create()), m = try #require(vhs_midi_queue_create())
        defer { vhs_audio_queue_destroy(a); vhs_midi_queue_destroy(m) }
        var status: Int32 = 0
        #expect(vhs_device_audio_start(a, 0, 0, -1, &status) == nil && status != 0)
        #expect(vhs_device_midi_start(m, 0, &status) == nil && status != 0)
        vhs_device_audio_stop(nil); vhs_device_midi_stop(nil)
    }
    @Test func serviceStartsOffAndUnavailableSourcesStayOffAfterStop() async throws {
        let service = InputService()
        let initial = await service.poll()
        #expect(initial.audioStatus == .off && initial.midiStatus == .off && !initial.audio.ready)
        try await service.selectMIDI(id: .min, channel: 2)
        await service.startMIDI()
        let missing = await service.poll()
        #expect(missing.midiStatus == .unavailable && missing.heldNotes == 0)
        await service.stopMIDI()
        #expect(await service.poll().midiStatus == .off)
        await service.shutdown()
        #expect(await service.poll().audioStatus == .off)
        await service.shutdown()
        try await service.configureMIDI(id: .min, channel: nil, enabled: true, revision: 100)
        #expect(await service.poll().midiStatus == .off)
    }
    @Test func realCoreMIDIVirtualSourceDeliversAndStopsThroughService() async throws {
        var client: MIDIClientRef = 0, endpoint: MIDIEndpointRef = 0
        #expect(MIDIClientCreateWithBlock("VHS automated source" as CFString, &client, { _ in }) == noErr)
        defer { MIDIClientDispose(client) }
        #expect(MIDISourceCreateWithProtocol(client, "VHS temporary input fixture" as CFString, ._1_0, &endpoint) == noErr)
        defer { MIDIEndpointDispose(endpoint) }
        var identity: MIDIUniqueID = 0
        #expect(MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &identity) == noErr)
        let service = InputService()
        try await service.selectMIDI(id: identity, channel: 3)
        await service.startMIDI()
        let started = await service.poll()
        #expect(started.midiStatus == .waiting)
        var list = MIDIEventList()
        let packet = MIDIEventListInit(&list, ._1_0)
        // Protocol-1 UMP channel 3, note 60, velocity 127; plus filtered channel 1.
        let words: [UInt32] = [0x20923C7F, 0x20903D7F]
        let added = words.withUnsafeBufferPointer { MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, 0, words.count, $0.baseAddress!) }
        #expect(list.numPackets == 1 && added.pointee.wordCount == 2)
        #expect(MIDIReceivedEventList(endpoint, &list) == noErr)
        var received = started
        for _ in 0..<100 {
            received = await service.poll()
            if received.heldNotes == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(received.heldNotes == 1 && received.lastMIDI?.channel == 3 && received.lastMIDI?.number == 60)
        #expect(received.lastMIDI?.sampleTime ?? 0 > 0)
        await service.stopMIDI()
        let stopped = await service.poll()
        #expect(stopped.heldNotes == 0 && stopped.lastMIDI == nil && stopped.midiStatus == .off)
        // The disposed input port must not deliver into the stopped service.
        #expect(MIDIReceivedEventList(endpoint, &list) == noErr)
        try await Task.sleep(for: .milliseconds(30))
        #expect(await service.poll().heldNotes == 0)
        await service.shutdown()
    }
    @Test func staleConfigurationCannotRestartStoppedCapture() async throws {
        let service = InputService()
        try await service.configureMIDI(id: .min, channel: nil, enabled: false, revision: 2)
        try await service.configureMIDI(id: .min, channel: nil, enabled: true, revision: 1)
        #expect(await service.poll().midiStatus == .off)
        await service.configureAudio(id: "missing", channels: AudioChannels(), enabled: false, revision: 2)
        await service.configureAudio(id: "missing", channels: AudioChannels(), enabled: true, revision: 1)
        #expect(await service.poll().audioStatus == .off)
        await service.shutdown()
    }
    @Test func virtualMIDIUnplugAndReconnectRetainsStableIdentityAndClearsNotes() async throws {
        var client: MIDIClientRef = 0, endpoint: MIDIEndpointRef = 0
        #expect(MIDIClientCreateWithBlock("VHS reconnect fixture" as CFString, &client, { _ in }) == noErr)
        defer { if endpoint != 0 { MIDIEndpointDispose(endpoint) }; MIDIClientDispose(client) }
        #expect(MIDISourceCreateWithProtocol(client, "VHS reconnect source" as CFString, ._1_0, &endpoint) == noErr)
        var identity: MIDIUniqueID = 0
        #expect(MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &identity) == noErr)
        let service = InputService()
        try await service.selectMIDI(id: identity, channel: nil)
        await service.startMIDI()
        #expect(await service.poll().midiStatus == .waiting)
        var list = MIDIEventList()
        let packet = MIDIEventListInit(&list, ._1_0)
        var word: UInt32 = 0x20903C7F
        let added = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &word)
        #expect(list.numPackets == 1 && added.pointee.wordCount == 1)
        #expect(MIDIReceivedEventList(endpoint, &list) == noErr)
        var snapshot = InputSnapshot()
        for _ in 0..<100 {
            snapshot = await service.poll()
            if snapshot.heldNotes == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(snapshot.heldNotes == 1)
        #expect(MIDIEndpointDispose(endpoint) == noErr); endpoint = 0
        await service.refreshCatalog()
        snapshot = await service.poll()
        #expect(snapshot.midiStatus == .unavailable && snapshot.heldNotes == 0 && snapshot.lastMIDI == nil)
        #expect(MIDISourceCreateWithProtocol(client, "VHS reconnected source" as CFString, ._1_0, &endpoint) == noErr)
        #expect(MIDIObjectSetIntegerProperty(endpoint, kMIDIPropertyUniqueID, identity) == noErr)
        await service.refreshCatalog()
        #expect(await service.poll().midiStatus == .waiting)
        #expect(MIDIReceivedEventList(endpoint, &list) == noErr)
        for _ in 0..<100 {
            snapshot = await service.poll()
            if snapshot.heldNotes == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(snapshot.heldNotes == 1)
        await service.shutdown()
    }
}
