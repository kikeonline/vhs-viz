import VHSRealtime

public struct MIDIEvent: Sendable, Equatable {
    public enum Kind: Sendable { case noteOn, noteOff, controller, reset }
    public let kind: Kind
    public let channel: Int // 1...16; reset uses 0 for all channels
    public let number: Int
    public let value: Double
    /// Packet containing the status/first running-status data byte, not completion packet.
    public let sampleTime: Int64
    public let offset: Int32
}

/// Worker-owned MIDI 1.0 byte-stream decoder. No Core MIDI or host APIs.
public struct MIDIDecoder {
    private var status: UInt8 = 0
    private var first: UInt8?
    private var time: Int64 = 0
    private var offset: Int32 = 0
    private var hasStart = false

    public init() {}
    public mutating func reset() { self = MIDIDecoder() }

    public mutating func accept(_ byte: UInt8, sampleTime: Int64, offset: Int32) -> MIDIEvent? {
        if byte >= 0xF8 {
            if byte == 0xFF {
                reset()
                return MIDIEvent(kind: .reset, channel: 0, number: 0, value: 0, sampleTime: sampleTime, offset: offset)
            }
            return nil // MIDI real-time messages may interleave inside a message.
        }
        if byte >= 0x80 {
            first = nil
            status = byte < 0xF0 ? byte : 0 // SysEx/system-common cancel running status.
            time = sampleTime; self.offset = offset; hasStart = status != 0
            return nil
        }
        guard status != 0 else { return nil }
        if !hasStart { time = sampleTime; self.offset = offset; hasStart = true }
        let type = status & 0xF0
        if type == 0xC0 || type == 0xD0 { hasStart = false; return nil }
        guard let number = first else { first = byte; return nil }
        first = nil; hasStart = false
        let kind: MIDIEvent.Kind
        switch type {
        case 0x80: kind = .noteOff
        case 0x90: kind = byte == 0 ? .noteOff : .noteOn
        case 0xB0: kind = .controller
        default: return nil // Poly pressure and pitch bend are outside this phase.
        }
        return MIDIEvent(kind: kind, channel: Int(status & 0x0F) + 1, number: Int(number),
                         value: Double(byte) / 127, sampleTime: time, offset: self.offset)
    }
}

/// Per-instance transient input, with independent channel/note/controller storage.
/// Sustain/other CCs are values only; MIDI learn and musical mapping policy belong to Phase 7.
public struct MIDIState: Sendable {
    public private(set) var selectedChannel: Int?
    private var notes = [Double](repeating: 0, count: 16 * 128)
    private var controllers = [Double](repeating: 0, count: 16 * 128)
    public var heldNoteCount: Int { notes.reduce(0) { $0 + ($1 > 0 ? 1 : 0) } }

    public init() {}
    public mutating func selectChannel(_ channel: Int?) throws {
        if let channel, !(1...16).contains(channel) { throw InputEngineError.invalidChannel }
        selectedChannel = channel; reset()
    }
    public func velocity(channel: Int, note: Int) -> Double {
        guard (1...16).contains(channel), (0...127).contains(note) else { return 0 }
        return notes[(channel - 1) * 128 + note]
    }
    public func controller(channel: Int, number: Int) -> Double {
        guard (1...16).contains(channel), (0...127).contains(number) else { return 0 }
        return controllers[(channel - 1) * 128 + number]
    }
    public mutating func reset() {
        notes = .init(repeating: 0, count: 16 * 128)
        controllers = .init(repeating: 0, count: 16 * 128)
    }
    /// False for filtered/invalid events; no fallback to another channel.
    @discardableResult public mutating func apply(_ event: MIDIEvent) -> Bool {
        if event.kind == .reset { reset(); return true }
        guard (1...16).contains(event.channel), (0...127).contains(event.number),
              event.value.isFinite, (0...1).contains(event.value),
              selectedChannel == nil || selectedChannel == event.channel else { return false }
        let base = (event.channel - 1) * 128, index = base + event.number
        switch event.kind {
        case .noteOn: notes[index] = event.value
        case .noteOff: notes[index] = 0
        case .controller:
            controllers[index] = event.value
            if event.number == 120 || (123...127).contains(event.number) {
                for i in base..<base + 128 { notes[i] = 0 }
            } else if event.number == 121 {
                for i in base..<base + 128 { controllers[i] = 0 }
            }
        case .reset: break
        }
        return true
    }
}

/// Single worker owner; C packet queue is the only cross-thread object.
public final class MIDIInput {
    public private(set) var state = MIDIState()
    private var decoder = MIDIDecoder()
    private var loss: UInt32 = 0
    public init() {}
    public func selectChannel(_ channel: Int?) throws {
        try state.selectChannel(channel); decoder.reset()
    }
    public func reset() { state.reset(); decoder.reset() }

    /// Events are bounded to <= 64*256 per poll; never called from a capture callback.
    /// On loss discard older generations and clear ALL held/controller/parser state.
    public func drain(_ queue: OpaquePointer) -> [MIDIEvent] {
        let before = vhs_midi_dropped(queue)
        if before != loss { reset() }
        var packet = VHSMIDIPacket(), events: [MIDIEvent] = []
        for _ in 0..<VHS_INPUT_QUEUE_SLOTS {
            guard vhs_midi_pop(queue, &packet) != 0 else { break }
            guard packet.generation == before else { continue }
            withUnsafeBytes(of: &packet.bytes) { bytes in
                for i in 0..<Int(packet.count) {
                    if let event = decoder.accept(bytes[i], sampleTime: packet.sampleTime, offset: packet.offset), state.apply(event) {
                        events.append(event)
                    }
                }
            }
        }
        let after = vhs_midi_dropped(queue)
        if after != before { reset(); events.removeAll() }
        loss = after
        return events
    }
}
