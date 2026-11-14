import Foundation
import VHSDeviceIO
import VHSInput

public enum AudioInputSource: Hashable, Sendable { case device(String), system }
public enum SystemAudioStatus: Int32, Sendable, CaseIterable {
    case off = 0, picking, starting, capturing, cancelled, denied, failed, ended, stopping
    public var isTerminal: Bool { [.off, .cancelled, .denied, .failed, .ended].contains(self) }
}

public struct AudioDevice: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let objectID: UInt32
    public let channels: Int
    public let sampleRate: Double
    public init(id: String, name: String, objectID: UInt32, channels: Int, sampleRate: Double) {
        self.id = id; self.name = name; self.objectID = objectID; self.channels = channels; self.sampleRate = sampleRate
    }
}
public struct MIDISource: Identifiable, Sendable, Equatable {
    public let id: Int32
    public let name: String
    public let endpoint: UInt32
    public init(id: Int32, name: String, endpoint: UInt32) { self.id = id; self.name = name; self.endpoint = endpoint }
}
public struct AudioChannels: Hashable, Codable, Sendable, Identifiable {
    public var left: Int
    public var right: Int?
    public init(left: Int = 0, right: Int? = nil) { self.left = left; self.right = right }
    public var id: String { "\(left):\(right ?? -1)" }
    public var title: String { right.map { "\(left + 1)–\($0 + 1) (stereo)" } ?? "\(left + 1) (mono)" }
    public func isValid(for count: Int) -> Bool {
        left >= 0 && left < min(count, Int(Int32.max)) &&
            (right == nil || (right! >= 0 && right! < min(count, Int(Int32.max)) && right != left))
    }
    public static func choices(count: Int) -> [Self] {
        (0..<max(0, min(256, count))).flatMap { channel in
            [Self(left: channel)] + (channel + 1 < min(count, 256) ? [Self(left: channel, right: channel + 1)] : [])
        }
    }
}
public enum InputStatus: Sendable, Equatable {
    case off, waiting, active, silent, unavailable, denied, restricted, invalidChannels, failed(Int32)
}
public struct InputSnapshot: Sendable {
    public var audioRevision = -1
    public var systemStatus: SystemAudioStatus = .off
    public var systemError: Int32 = 0
    public var audioDevices: [AudioDevice] = []
    public var midiSources: [MIDISource] = []
    public var audioStatus: InputStatus = .off
    public var midiStatus: InputStatus = .off
    public var audio = AudioSignals()
    public var lastMIDI: MIDIEvent?
    public var heldNotes = 0
    public var audioDrops: UInt32 = 0
    public var midiLosses: UInt32 = 0
    public var catalogError: Int32?
    public init() {}
}

/// Read-only enumeration. No audio unit is created and no permission is requested here.
public enum InputCatalog {
    public static func read() -> (audio: [AudioDevice], midi: [MIDISource], error: Int32?) {
        var audio = [VHSDeviceInfo](repeating: VHSDeviceInfo(), count: Int(VHS_DEVICE_LIMIT))
        var midi = audio
        let a = vhs_list_audio_devices(&audio, UInt32(audio.count)), m = vhs_list_midi_sources(&midi, UInt32(midi.count))
        let devices = audio.prefix(Int(max(0, a))).map { info in
            var info = info
            let uid = withUnsafeBytes(of: &info.uid) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
            let name = withUnsafeBytes(of: &info.name) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
            return AudioDevice(id: uid, name: name, objectID: info.objectID, channels: Int(info.channels), sampleRate: info.sampleRate)
        }
        let sources = midi.prefix(Int(max(0, m))).map { info in
            var info = info
            let name = withUnsafeBytes(of: &info.name) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
            return MIDISource(id: info.uniqueID, name: name, endpoint: info.objectID)
        }
        // Duplicate identities are unsafe to reconnect automatically. Exclude ambiguous IDs.
        let audioCounts = Dictionary(grouping: devices, by: \.id)
        let midiCounts = Dictionary(grouping: sources, by: \.id)
        return (devices.filter { audioCounts[$0.id]?.count == 1 }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
                sources.filter { midiCounts[$0.id]?.count == 1 }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
                a < 0 ? a : (m < 0 ? m : nil))
    }
}

/// Pure reconnect policy: retain stable selection, never substitute a default device.
public enum InputResolution {
    public static func audio(id: String, channels: AudioChannels, devices: [AudioDevice]) -> AudioDevice? {
        let matches = devices.filter { $0.id == id }
        guard matches.count == 1, channels.isValid(for: matches[0].channels) else { return nil }
        return matches[0]
    }
    public static func midi(id: Int32?, sources: [MIDISource]) -> MIDISource? {
        let matches = sources.filter { $0.id == id }
        return matches.count == 1 ? matches[0] : nil
    }
}
