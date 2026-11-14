import Testing
@testable import VHSInput
import VHSRealtime

private func send(_ bytes: [UInt8], to queue: OpaquePointer, time: Int64 = 0, offset: Int32 = 0) -> Int32 {
    bytes.withUnsafeBufferPointer { vhs_midi_push(queue, $0.baseAddress, UInt32(bytes.count), time, offset) }
}

@Test func runningStatusPacketSplitAndTimestampOwnership() throws {
    let q = try #require(vhs_midi_queue_create()); defer { vhs_midi_queue_destroy(q) }
    let input = MIDIInput()
    #expect(send([0x92, 60], to: q, time: 100, offset: 17) == 1)
    #expect(input.drain(q).isEmpty)
    #expect(send([0xF8, 127, 61, 64], to: q, time: 200, offset: 3) == 1)
    let events = input.drain(q)
    #expect(events.count == 2)
    #expect(events[0].channel == 3 && events[0].number == 60 && events[0].value == 1)
    #expect(events[0].sampleTime == 100 && events[0].offset == 17)
    #expect(events[1].sampleTime == 200 && events[1].offset == 3)
    #expect(input.state.heldNoteCount == 2)
    #expect(send([60, 0, 0x82, 61, 32], to: q) == 1)
    #expect(input.drain(q).allSatisfy { $0.kind == .noteOff })
    #expect(input.state.heldNoteCount == 0)
}

@Test(arguments: Array(1...16))
func channelsVelocityAndControllerNormalization(_ channel: Int) throws {
    let q = try #require(vhs_midi_queue_create()); defer { vhs_midi_queue_destroy(q) }
    let input = MIDIInput(), nibble = UInt8(channel - 1)
    try input.selectChannel(channel)
    #expect(send([0x90 | nibble, 127, 1, 0xB0 | nibble, 74, 127], to: q) == 1)
    #expect(input.drain(q).count == 2)
    #expect(input.state.velocity(channel: channel, note: 127) == 1.0 / 127)
    #expect(input.state.controller(channel: channel, number: 74) == 1)
    let other = channel == 16 ? 1 : channel + 1
    #expect(send([0x90 | UInt8(other - 1), 60, 127], to: q) == 1)
    #expect(input.drain(q).isEmpty && input.state.heldNoteCount == 1)
    try input.selectChannel(nil)
    #expect(input.state.heldNoteCount == 0 && input.state.controller(channel: channel, number: 74) == 0)
    #expect(throws: InputEngineError.self) { try input.selectChannel(0) }
    #expect(throws: InputEngineError.self) { try input.selectChannel(17) }
}

@Test func allNotesOffAndControllerResetAreChannelScoped() throws {
    let q = try #require(vhs_midi_queue_create()); defer { vhs_midi_queue_destroy(q) }
    let input = MIDIInput()
    for control in [UInt8(120), 123, 124, 125, 126, 127] {
        #expect(send([0x90, 60, 127, 0x91, 60, 100, 0xB0, control, 0], to: q) == 1)
        _ = input.drain(q)
        #expect(input.state.velocity(channel: 1, note: 60) == 0)
        #expect(input.state.velocity(channel: 2, note: 60) == 100.0 / 127)
    }
    #expect(send([0xB1, 74, 100, 121, 0], to: q) == 1)
    _ = input.drain(q)
    #expect(input.state.controller(channel: 2, number: 74) == 0)
    #expect(input.state.heldNoteCount == 1) // Reset Controllers does not synthesize note releases.
    #expect(send([0xFF], to: q) == 1)
    #expect(input.drain(q).first?.kind == .reset && input.state.heldNoteCount == 0)
}

@Test func ignoredSystemMessagesAndMalformedStreamsDoNotMakeNotes() throws {
    let q = try #require(vhs_midi_queue_create()); defer { vhs_midi_queue_destroy(q) }
    let input = MIDIInput()
    let malformed: [[UInt8]] = [
        [60, 127], [0xF0, 0x01, 60, 127, 0xF7, 60, 127],
        [0x90, 60, 0xF1, 0x7F, 127], [0x90, 60, 0xF2, 1, 2, 127],
        [0x90, 60, 0xF3, 1, 127], [0x90, 60, 0xF6, 127],
        [0x90, 60, 0xC0, 1, 60, 127], [0xD0, 1, 60, 127],
        [0xA0, 60, 127], [0xE0, 60, 127]
    ]
    for bytes in malformed {
        input.reset()
        #expect(send(bytes, to: q) == 1)
        #expect(input.drain(q).isEmpty && input.state.heldNoteCount == 0)
    }
    #expect(send([0x90, 60, 0xFA, 0xF8, 0xFE, 127], to: q) == 1)
    #expect(input.drain(q).count == 1 && input.state.heldNoteCount == 1)
}

@Test func midiOverflowDisconnectAndInvalidPacketsCannotStickNotes() throws {
    let q = try #require(vhs_midi_queue_create()); defer { vhs_midi_queue_destroy(q) }
    let input = MIDIInput()
    #expect(send([0x90, 60, 127], to: q) == 1); _ = input.drain(q)
    #expect(input.state.heldNoteCount == 1)
    for _ in 0..<64 { #expect(send([0x90, 61, 127], to: q) == 1) }
    #expect(send([0x80, 60, 0], to: q) == 0)
    #expect(input.drain(q).isEmpty && input.state.heldNoteCount == 0)
    #expect(send([60, 127], to: q) == 1)
    #expect(input.drain(q).isEmpty) // Running status also cleared.
    #expect(send([0x90, 60, 127], to: q) == 1); _ = input.drain(q)
    vhs_midi_mark_gap(q)
    #expect(input.drain(q).isEmpty && input.state.heldNoteCount == 0)
    #expect(send([0x90, 61, 127], to: q) == 1); _ = input.drain(q)
    #expect(vhs_midi_push(q, nil, 1, 0, 0) == 0)
    #expect(input.drain(q).isEmpty && input.state.heldNoteCount == 0)
    #expect(send([UInt8](repeating: 0, count: 257), to: q) == 0)
    #expect(send([], to: q) == 0)
    #expect(send([0x90], to: q, offset: -1) == 0)
}

@Test func midiBurstQueueWrapAndInstanceIsolation() async throws {
    let q = try #require(vhs_midi_queue_create()), other = try #require(vhs_midi_queue_create())
    defer { vhs_midi_queue_destroy(q); vhs_midi_queue_destroy(other) }
    let a = MIDIInput(), b = MIDIInput()
    let burst: [UInt8] = [0x90] + (0..<85).flatMap { [UInt8($0), UInt8(127)] }
    #expect(send(burst, to: q) == 1)
    #expect(a.drain(q).count == 85 && a.state.heldNoteCount == 85 && b.state.heldNoteCount == 0)
    let address = UInt(bitPattern: q)
    let producer = Task.detached {
        let pointer = OpaquePointer(bitPattern: address)!
        for i in 0..<10_000 {
            var byte = UInt8(i % 128)
            while vhs_midi_push(pointer, &byte, 1, Int64(i), Int32(i % 512)) == 0 { await Task.yield() }
        }
    }
    var packet = VHSMIDIPacket()
    for i in 0..<10_000 {
        while vhs_midi_pop(q, &packet) == 0 { await Task.yield() }
        #expect(packet.sampleTime == Int64(i) && packet.offset == Int32(i % 512))
        #expect(withUnsafeBytes(of: &packet.bytes) { $0[0] } == UInt8(i % 128))
    }
    await producer.value
    #expect(vhs_midi_pop(other, &packet) == 0 && vhs_midi_dropped(other) == 0)
}

@Test func midiRecoveryKeepsOnlyPacketsAfterLossEpoch() throws {
    let q = try #require(vhs_midi_queue_create()); defer { vhs_midi_queue_destroy(q) }
    let input = MIDIInput()
    #expect(send([0x90, 60, 127], to: q) == 1)
    vhs_midi_mark_gap(q)
    #expect(send([0x90, 61, 127], to: q) == 1)
    let events = input.drain(q)
    #expect(events.count == 1 && events[0].number == 61)
    #expect(input.state.velocity(channel: 1, note: 60) == 0)
    #expect(input.state.velocity(channel: 1, note: 61) == 1)
    // The consumer may span polls: a retained older epoch must remain distinguishable.
    var packet = VHSMIDIPacket()
    #expect(send([0x90, 62, 127], to: q) == 1)
    #expect(vhs_midi_pop(q, &packet) == 1)
    vhs_midi_mark_gap(q)
    #expect(packet.generation != vhs_midi_dropped(q))
    #expect(input.drain(q).isEmpty && input.state.heldNoteCount == 0)
}
