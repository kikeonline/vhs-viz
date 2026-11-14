import AppKit
import AVFoundation
import Observation
import VHSDevices
import VHSInput

@Observable final class StandaloneInputs {
    var snapshot = InputSnapshot()
    var showsInputs = false
    private(set) var audioID: String
    private(set) var usesSystemAudio = false
    var audioSource: AudioInputSource { usesSystemAudio ? .system : .device(audioID) }
    private(set) var channels: AudioChannels
    private(set) var midiID: Int32?
    private(set) var midiChannel: Int?
    private(set) var wantsAudio = false
    private(set) var wantsMIDI = false
    private(set) var requestingAccess = false
    @ObservationIgnored private let service = InputService()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var audioRevision = 0
    @ObservationIgnored private var midiRevision = 0
    @ObservationIgnored private let isolated = ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil || CommandLine.arguments.contains("--selftest") || CommandLine.arguments.contains("--input-selftest")

    init() {
        let defaults = UserDefaults.standard
        audioID = defaults.string(forKey: "input.audioUID") ?? ""
        usesSystemAudio = defaults.string(forKey: "input.audioKind") == "system"
        channels = defaults.data(forKey: "input.channels").flatMap { try? JSONDecoder().decode(AudioChannels.self, from: $0) } ?? AudioChannels()
        midiID = (defaults.object(forKey: "input.midiID") as? NSNumber)?.int32Value
        let channel = defaults.integer(forKey: "input.midiChannel")
        midiChannel = (1...16).contains(channel) ? channel : nil
        if isolated { audioID = ""; usesSystemAudio = false; channels = AudioChannels(); midiID = nil; midiChannel = nil }
    }
    func startPolling() {
        guard task == nil, !isolated else { return }
        task = Task { [weak self, service] in
            while !Task.isCancelled {
                let value = await service.poll()
                guard let self, !Task.isCancelled else { return }
                var next = value
                if value.audioRevision < audioRevision {
                    next.audio = snapshot.audio; next.audioStatus = snapshot.audioStatus
                    next.systemStatus = snapshot.systemStatus; next.systemError = snapshot.systemError
                } else {
                    if case .failed = value.audioStatus { wantsAudio = false }
                    if usesSystemAudio, value.systemStatus.isTerminal { wantsAudio = false }
                }
                snapshot = next
                if case .failed = value.midiStatus { wantsMIDI = false }
                try? await Task.sleep(for: .milliseconds(wantsAudio || wantsMIDI ? 67 : 1000))
            }
        }
    }
    func refresh() { guard !isolated else { return }; Task { await service.refreshCatalog() } }
    func fixture(_ value: InputSnapshot, audioRunning: Bool, midiRunning: Bool) {
        guard isolated else { return }
        snapshot = value; wantsAudio = audioRunning; wantsMIDI = midiRunning
    }
    func chooseAudio(_ id: String) {
        if usesSystemAudio { wantsAudio = false }
        usesSystemAudio = false
        audioID = id; channels = AudioChannels()
        applyAudio(); saveChoices()
    }
    func chooseSource(_ value: AudioInputSource) {
        switch value {
        case .device(let id): chooseAudio(id)
        case .system:
            usesSystemAudio = true; wantsAudio = false; requestingAccess = false
            applyAudio(); saveChoices()
        }
    }
    func chooseChannels(_ value: AudioChannels) { channels = value; applyAudio(); saveChoices() }
    func chooseMIDI(_ id: Int32?) { midiID = id; applyMIDI(); saveChoices() }
    func chooseMIDIChannel(_ channel: Int?) { midiChannel = channel; applyMIDI(); saveChoices() }
    func startAudio() {
        guard !isolated else { return }
        if usesSystemAudio { wantsAudio = true; applyAudio(); return }
        guard InputResolution.audio(id: audioID, channels: channels, devices: snapshot.audioDevices) != nil else {
            snapshot.audioStatus = snapshot.audioDevices.contains { $0.id == audioID } ? .invalidChannels : .unavailable
            return
        }
        audioRevision += 1; let revision = audioRevision
        requestingAccess = true
        Task {
            let authorized: Bool
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: authorized = true
            case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .audio)
            default: authorized = false
            }
            guard revision == audioRevision else { return }
            requestingAccess = false
            guard authorized else {
                snapshot.audioStatus = AVCaptureDevice.authorizationStatus(for: .audio) == .restricted ? .restricted : .denied
                return
            }
            wantsAudio = true; applyAudio()
        }
    }
    func stopAudio() { requestingAccess = false; wantsAudio = false; applyAudio() }
    func startMIDI() { wantsMIDI = true; applyMIDI() }
    func stopMIDI() { wantsMIDI = false; applyMIDI() }
    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") { NSWorkspace.shared.open(url) }
    }
    func openSystemAudioSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
    }
    func shutdown() async {
        audioRevision += 1; midiRevision += 1
        task?.cancel(); task = nil; wantsAudio = false; wantsMIDI = false; requestingAccess = false
        await service.shutdown()
    }
    private func applyAudio() {
        audioRevision += 1
        guard !isolated else { return }
        snapshot.audio = AudioSignals()
        snapshot.audioStatus = wantsAudio ? .waiting : .off
        snapshot.systemStatus = usesSystemAudio && wantsAudio ? .picking : .off
        let revision = audioRevision, id = audioID, channels = channels, enabled = wantsAudio
        let system = usesSystemAudio
        Task {
            if system { await service.configureSystemAudio(enabled: enabled, revision: revision) }
            else { await service.configureAudio(id: id, channels: channels, enabled: enabled, revision: revision) }
        }
    }
    private func applyMIDI() {
        midiRevision += 1
        guard !isolated else { return }
        let revision = midiRevision, id = midiID, channel = midiChannel, enabled = wantsMIDI
        Task { try? await service.configureMIDI(id: id, channel: channel, enabled: enabled, revision: revision) }
    }
    private func saveChoices() {
        guard !isolated else { return }
        let defaults = UserDefaults.standard
        defaults.set(audioID, forKey: "input.audioUID")
        defaults.set(usesSystemAudio ? "system" : "device", forKey: "input.audioKind")
        defaults.set(try? JSONEncoder().encode(channels), forKey: "input.channels")
        defaults.set(midiID.map { NSNumber(value: $0) }, forKey: "input.midiID")
        defaults.set(midiChannel ?? 0, forKey: "input.midiChannel")
    }
}
