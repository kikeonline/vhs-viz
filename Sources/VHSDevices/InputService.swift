import AVFoundation
import Foundation
import VHSInput
import VHSRealtime
import VHSDeviceIO
import VHSSystemIO

/// All native control, queue consumption and DSP stay off MainActor on this actor.
public actor InputService {
    private var runtime: CaptureRuntime?
    private var snapshot = InputSnapshot()
    private var audioID = "", midiID: Int32?
    private var channels = AudioChannels(), midiChannel: Int?
    private var wantsAudio = false, wantsMIDI = false
    private var wantsSystem = false
    private var audioDevice: AudioDevice?, midiSource: MIDISource?
    private var polls = 0, unchangedPolls = 0
    private var lastFrame: Int64?
    private var audioRevision = -1, midiRevision = -1
    private var isShutDown = false
    public init() {}
    public func configureAudio(id: String, channels: AudioChannels, enabled: Bool, revision: Int) {
        guard !isShutDown, revision > audioRevision else { return }; audioRevision = revision
        stopSystemRuntime()
        selectAudio(id: id, channels: channels)
        if enabled { startAudio() } else { stopAudio() }
    }
    public func configureSystemAudio(enabled: Bool, revision: Int) {
        guard !isShutDown, revision > audioRevision else { return }; audioRevision = revision
        wantsAudio = false; stopAudioRuntime()
        if !enabled { stopSystemRuntime(); snapshot.audioStatus = .off; return }
        do {
            if runtime == nil { runtime = try CaptureRuntime() }
            guard let r = runtime else { return }
            if r.system == nil { r.system = vhs_system_create() }
            guard let system = r.system else { throw InputEngineError.transformUnavailable }
            wantsSystem = true; snapshot.audio = AudioSignals(); snapshot.audioStatus = .waiting
            snapshot.systemStatus = .picking; snapshot.systemError = 0
            vhs_system_present(system)
        } catch { snapshot.systemStatus = .failed; snapshot.audioStatus = .failed(-2) }
    }
    public func configureMIDI(id: Int32?, channel: Int?, enabled: Bool, revision: Int) throws {
        guard !isShutDown, revision > midiRevision else { return }
        try selectMIDI(id: id, channel: channel); midiRevision = revision
        if enabled { startMIDI() } else { stopMIDI() }
    }
    public func refreshCatalog() { polls = 0 }

    public func selectAudio(id: String, channels: AudioChannels) {
        if audioID != id || self.channels != channels {
            stopAudioRuntime(); audioID = id; self.channels = channels
        }
    }
    public func selectMIDI(id: Int32?, channel: Int?) throws {
        guard channel == nil || (1...16).contains(channel!) else { throw InputEngineError.invalidChannel }
        if midiID != id || midiChannel != channel {
            stopMIDIRuntime(); midiID = id; midiChannel = channel
        }
    }
    public func startAudio() {
        guard !isShutDown else { return }
        wantsAudio = true; polls = 0
    }
    public func stopAudio() { wantsAudio = false; stopAudioRuntime(); snapshot.audioStatus = .off }
    public func startMIDI() { guard !isShutDown else { return }; wantsMIDI = true; polls = 0 }
    public func stopMIDI() { wantsMIDI = false; stopMIDIRuntime(); snapshot.midiStatus = .off }
    public func shutdown() async {
        isShutDown = true; stopSystemRuntime(); stopAudio(); stopMIDI()
        // Native stop is asynchronous on the main queue; do not block it or the sample queue.
        for _ in 0..<500 {
            guard let system = runtime?.system, vhs_system_state(system) != VHSSystemOff.rawValue else { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        runtime = nil // Native receiver/stop completions retain their own queue lifetime if the OS is slow.
    }

    public func poll() -> InputSnapshot {
        snapshot.midiEvents = []
        guard !isShutDown else { return snapshot }
        do {
            if runtime == nil { runtime = try CaptureRuntime() }
            guard let r = runtime else { return snapshot }
            if polls % 15 == 0 {
                let catalog = InputCatalog.read()
                snapshot.audioDevices = catalog.audio; snapshot.midiSources = catalog.midi; snapshot.catalogError = catalog.error
            }
            polls += 1
            if let system = r.system, !wantsSystem, vhs_system_state(system) == VHSSystemOff.rawValue {
                vhs_system_release(system); r.system = nil
                if !snapshot.systemStatus.isTerminal { snapshot.systemStatus = .off }
            }
            if r.system != nil && !wantsSystem && wantsAudio { snapshot.audioStatus = .waiting }
            reconcile(r)
            if let capture = r.audio, vhs_device_audio_error(capture) != 0 {
                let status = vhs_device_audio_error(capture)
                let priorDevice = audioDevice
                stopAudioRuntime()
                let catalog = InputCatalog.read()
                snapshot.audioDevices = catalog.audio; snapshot.midiSources = catalog.midi; snapshot.catalogError = catalog.error
                if let current = InputResolution.audio(id: audioID, channels: channels, devices: catalog.audio) {
                    if current != priorDevice { reconcile(r) }
                    else { wantsAudio = false; snapshot.audioStatus = .failed(status) }
                } else {
                    snapshot.audioStatus = catalog.audio.contains { $0.id == audioID } ? .invalidChannels : .unavailable
                }
            }
            if r.audio != nil { try r.analyzer.drain(r.audioQueue) }
            let events = r.midi.drain(r.midiQueue)
            snapshot.midiEvents = events
            snapshot.midiSequence &+= 1
            if let event = events.last { snapshot.lastMIDI = event }
            if vhs_midi_dropped(r.midiQueue) != snapshot.midiLosses && events.isEmpty { snapshot.lastMIDI = nil }
            snapshot.heldNotes = r.midi.state.heldNoteCount
            snapshot.midiLosses = vhs_midi_dropped(r.midiQueue)
            snapshot.audioDrops = vhs_audio_dropped(r.audioQueue)
            if let system = r.system, wantsSystem {
                snapshot.systemStatus = SystemAudioStatus(rawValue: vhs_system_state(system)) ?? .failed
                snapshot.systemError = vhs_system_error(system)
                let queue = vhs_system_queue(system)!
                if snapshot.systemStatus == .capturing {
                    if snapshot.systemError != 0 {
                        vhs_system_stop(system); wantsSystem = false
                        snapshot.systemStatus = .failed; snapshot.audioStatus = .failed(snapshot.systemError); snapshot.audio = AudioSignals()
                    } else {
                        try r.analyzer.drain(queue)
                        snapshot.audio = r.analyzer.signals
                        if snapshot.audio.ready, lastFrame != snapshot.audio.endSampleTime { unchangedPolls = 0 }
                        else { unchangedPolls += 1 }
                        lastFrame = snapshot.audio.ready ? snapshot.audio.endSampleTime : nil
                        if unchangedPolls >= 15 { snapshot.audio = AudioSignals() }
                        snapshot.audioStatus = !snapshot.audio.ready ? .waiting : snapshot.audio.peak < 0.000001 ? .silent : .active
                    }
                } else {
                    snapshot.audio = AudioSignals()
                    switch snapshot.systemStatus {
                    case .denied: snapshot.audioStatus = .denied
                    case .failed: snapshot.audioStatus = .failed(snapshot.systemError)
                    case .cancelled, .ended, .off: snapshot.audioStatus = .off
                    default: snapshot.audioStatus = .waiting
                    }
                    if snapshot.systemStatus.isTerminal { wantsSystem = false }
                }
                snapshot.audioDrops = vhs_audio_dropped(queue)
            }
            if r.audio != nil {
                let signals = r.analyzer.signals
                if signals.ready, lastFrame == signals.endSampleTime { unchangedPolls += 1 }
                else if !signals.ready { unchangedPolls += 1 }
                else { unchangedPolls = 0 }
                lastFrame = signals.ready ? signals.endSampleTime : nil
                if unchangedPolls >= 45 {
                    stopAudioRuntime(); wantsAudio = false; snapshot.audioStatus = .failed(-1)
                } else if unchangedPolls >= 15 {
                    snapshot.audio = AudioSignals(); snapshot.audioStatus = .waiting
                } else {
                    snapshot.audio = signals
                    snapshot.audioStatus = !signals.ready ? .waiting : signals.peak < 0.000001 ? .silent : .active
                }
            }
            if r.midiCapture != nil { snapshot.midiStatus = snapshot.lastMIDI == nil ? .waiting : .active }
        } catch {
            stopAudioRuntime(); stopMIDIRuntime(); wantsAudio = false; wantsMIDI = false
            snapshot.audioStatus = .failed(-2); snapshot.midiStatus = .failed(-2)
        }
        snapshot.midiRevision = midiRevision
        snapshot.audioRevision = audioRevision
        if let r = runtime {
            snapshot.mappingInputs = r.midi.state.mappingInputs(audio: snapshot.audio, available: r.midiCapture != nil)
        }
        return snapshot
    }

    private func reconcile(_ r: CaptureRuntime) {
        if wantsAudio && r.system == nil {
            if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
                stopAudioRuntime()
                snapshot.audioStatus = AVCaptureDevice.authorizationStatus(for: .audio) == .restricted ? .restricted : .denied
            } else if let device = InputResolution.audio(id: audioID, channels: channels, devices: snapshot.audioDevices) {
                if audioDevice != device { stopAudioRuntime() }
                if r.audio == nil {
                    var status: Int32 = 0
                    r.audio = vhs_device_audio_start(r.audioQueue, device.objectID, Int32(channels.left), Int32(channels.right ?? -1), &status)
                    if r.audio == nil { wantsAudio = false; snapshot.audioStatus = .failed(status) }
                    else { audioDevice = device; unchangedPolls = 0; lastFrame = nil; snapshot.audioStatus = .waiting }
                }
            } else {
                stopAudioRuntime()
                snapshot.audioStatus = snapshot.audioDevices.contains { $0.id == audioID } ? .invalidChannels : .unavailable
            }
        }
        if wantsMIDI {
            if let source = InputResolution.midi(id: midiID, sources: snapshot.midiSources) {
                if midiSource != source { stopMIDIRuntime() }
                if r.midiCapture == nil {
                    var status: Int32 = 0
                    try? r.midi.selectChannel(midiChannel)
                    r.midiCapture = vhs_device_midi_start(r.midiQueue, source.endpoint, &status)
                    if r.midiCapture == nil { wantsMIDI = false; snapshot.midiStatus = .failed(status) }
                    else { midiSource = source; snapshot.midiStatus = .waiting }
                }
            } else { stopMIDIRuntime(); snapshot.midiStatus = .unavailable }
        }
    }
    private func stopSystemRuntime() {
        wantsSystem = false
        if let r = runtime, let system = r.system {
            vhs_system_stop(system); r.analyzer.reset()
            snapshot.systemStatus = .stopping; snapshot.audio = AudioSignals()
        }
    }
    private func stopAudioRuntime() {
        guard let r = runtime else { return }
        if let audio = r.audio { vhs_device_audio_stop(audio); r.audio = nil }
        // Stop joins the producer before the worker resets/discards the queue.
        var chunk = VHSAudioChunk()
        for _ in 0..<VHS_INPUT_QUEUE_SLOTS { if vhs_audio_pop(r.audioQueue, &chunk) == 0 { break } }
        r.analyzer.reset(); snapshot.audio = AudioSignals(); audioDevice = nil
        unchangedPolls = 0; lastFrame = nil
    }
    private func stopMIDIRuntime() {
        guard let r = runtime else { return }
        if let midi = r.midiCapture { vhs_device_midi_stop(midi); r.midiCapture = nil }
        var packet = VHSMIDIPacket()
        for _ in 0..<VHS_INPUT_QUEUE_SLOTS { if vhs_midi_pop(r.midiQueue, &packet) == 0 { break } }
        r.midi.reset(); snapshot.lastMIDI = nil; snapshot.heldNotes = 0; midiSource = nil
    }
}

private final class CaptureRuntime {
    let audioQueue: OpaquePointer, midiQueue: OpaquePointer
    let analyzer: AudioAnalyzer
    let midi = MIDIInput()
    var audio: OpaquePointer?, midiCapture: OpaquePointer?
    var system: VHSSystemSession?
    init() throws {
        analyzer = try AudioAnalyzer()
        guard let a = vhs_audio_queue_create() else { throw InputEngineError.transformUnavailable }
        guard let m = vhs_midi_queue_create() else { vhs_audio_queue_destroy(a); throw InputEngineError.transformUnavailable }
        audioQueue = a; midiQueue = m
    }
    deinit {
        if let audio { vhs_device_audio_stop(audio) }
        if let midiCapture { vhs_device_midi_stop(midiCapture) }
        if let system { vhs_system_release(system) }
        vhs_audio_queue_destroy(audioQueue); vhs_midi_queue_destroy(midiQueue)
    }
}
