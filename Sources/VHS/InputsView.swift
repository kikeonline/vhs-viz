import SwiftUI
import VHSSignal
import VHSDevices
import VHSInput

struct InputsView: View {
    let inputs: StandaloneInputs
    private var data: InputSnapshot { inputs.snapshot }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("Inputs").font(KitType.title).gridProbe("inputs-title", area: "inputs")
                audio.padding(.bottom, Space.xl).overlay(alignment: .bottom) { Divider() }
                    .gridProbe("inputs-audio", area: "inputs")
                midi.gridProbe("inputs-midi", area: "inputs")
                if data.catalogError != nil {
                    Text("Unable to refresh inputs. Reopen Inputs to retry.")
                        .font(KitType.meta).foregroundStyle(Ink.warning)
                }
            }.padding(Space.margin).gridArea("inputs")
        }
        .frame(width: Layout.inputWidth, height: Layout.inputMaxHeight)
        .signalTheme()
        .onAppear { inputs.refresh() }
    }
    private var audio: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Audio").font(KitType.section).gridProbe("input-audio-title", area: "input-audio-body")
            Picker("Audio input", selection: Binding(get: { inputs.audioSource }, set: inputs.chooseSource)) {
                Text("Choose Input").tag(AudioInputSource.device(""))
                Text("System Audio").tag(AudioInputSource.system)
                if !inputs.audioID.isEmpty, !data.audioDevices.contains(where: { $0.id == inputs.audioID }) {
                    Text("Selected input unavailable").tag(AudioInputSource.device(inputs.audioID))
                }
                ForEach(data.audioDevices) { Text($0.name).tag(AudioInputSource.device($0.id)) }
            }.help(inputs.usesSystemAudio ? "Choose apps or a display through the macOS sharing picker" : selectedDevice?.name ?? "Choose a microphone or audio interface").disabled(inputs.requestingAccess)
                .frame(maxWidth: .infinity, alignment: .leading).gridProbe("input-device", area: "input-audio-body")
            if inputs.usesSystemAudio {
                Text("Stereo · 48 kHz").font(KitType.meta).foregroundStyle(Ink.secondary)
                    .gridProbe("input-system-format", area: "input-audio-body")
            } else {
              Picker("Channels", selection: Binding(get: { inputs.channels }, set: inputs.chooseChannels)) {
                if !channelChoices.contains(inputs.channels) { Text("Selected channels unavailable").tag(inputs.channels) }
                ForEach(channelChoices) { Text($0.title).tag($0) }
            }.disabled(selectedDevice == nil || inputs.requestingAccess)
                .frame(maxWidth: .infinity, alignment: .leading).gridProbe("input-channels", area: "input-audio-body")
            }
            HStack {
                Button(inputs.wantsAudio || inputs.requestingAccess ? "Stop Audio" : inputs.usesSystemAudio ? "Choose Audio to Share…" : "Start Audio") {
                    if inputs.wantsAudio || inputs.requestingAccess { inputs.stopAudio() } else { inputs.startAudio() }
                }.disabled(!inputs.usesSystemAudio && inputs.audioID.isEmpty)
                Spacer()
                if !inputs.usesSystemAudio, let device = selectedDevice {
                    Text("\(device.sampleRate / 1000, specifier: "%.1f") kHz").font(KitType.meta).foregroundStyle(Ink.secondary)
                }
            }.gridProbe("input-audio-action", area: "input-audio-body")
            status(audioStatus, error: isProblem(data.audioStatus)).gridProbe("input-audio-status", area: "input-audio-body")
            if !inputs.usesSystemAudio, data.audioStatus == .denied {
                Button("Open Microphone Settings") { inputs.openMicrophoneSettings() }
                    .gridProbe("input-permission-action", area: "input-audio-body")
            }
            if inputs.usesSystemAudio, data.systemStatus == .denied {
                Button("Open Screen & Audio Settings") { inputs.openSystemAudioSettings() }
                    .gridProbe("input-sharing-settings", area: "input-audio-body")
            }
            Grid(horizontalSpacing: Space.lg, verticalSpacing: Space.md) {
                GridRow {
                    SignalMeter("RMS", reading: decibels(data.audio.rms), level: level(data.audio.rms))
                    SignalMeter("Peak", reading: decibels(data.audio.peak), level: level(data.audio.peak))
                }
                GridRow {
                    normalized("Low", data.audio.low)
                    normalized("Mid", data.audio.mid)
                }
                GridRow {
                    normalized("High", data.audio.high)
                    normalized("Transient", data.audio.transient)
                }
            }.gridProbe("input-audio-meters", area: "input-audio-body")
            if data.audio.clipped { status("Clipped input. Lower the source level.", error: true) }
            if data.audio.invalidSamples > 0 { status("Invalid samples ignored: \(data.audio.invalidSamples)", error: true) }
            if data.audioDrops > 0 { status("Audio blocks dropped: \(data.audioDrops)", error: true) }
        }.gridArea("input-audio-body", inset: 0)
    }
    private var midi: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("MIDI").font(KitType.section).gridProbe("input-midi-title", area: "input-midi-body")
            Picker("MIDI source", selection: Binding(get: { inputs.midiID }, set: inputs.chooseMIDI)) {
                Text("Choose Source").tag(Int32?.none)
                if let id = inputs.midiID, !data.midiSources.contains(where: { $0.id == id }) {
                    Text("Selected source unavailable").tag(Optional(id))
                }
                ForEach(data.midiSources) { Text($0.name).tag(Optional($0.id)) }
            }.help(data.midiSources.first { $0.id == inputs.midiID }?.name ?? "Choose a hardware or virtual MIDI source")
                .frame(maxWidth: .infinity, alignment: .leading).gridProbe("input-midi-source", area: "input-midi-body")
            Picker("MIDI channel", selection: Binding(get: { inputs.midiChannel }, set: inputs.chooseMIDIChannel)) {
                Text("Omni").tag(Int?.none)
                ForEach(1...16, id: \.self) { Text("Channel \($0)").tag(Optional($0)) }
            }.frame(maxWidth: .infinity, alignment: .leading).gridProbe("input-midi-channel", area: "input-midi-body")
            Button(inputs.wantsMIDI ? "Stop MIDI" : "Start MIDI") {
                if inputs.wantsMIDI { inputs.stopMIDI() } else { inputs.startMIDI() }
            }.disabled(inputs.midiID == nil).gridProbe("input-midi-action", area: "input-midi-body")
            status(midiStatus, error: isProblem(data.midiStatus)).gridProbe("input-midi-status", area: "input-midi-body")
            Text("Held notes: \(data.heldNotes)").font(KitType.value).monospacedDigit().gridProbe("input-midi-held", area: "input-midi-body")
            Text(eventDescription).font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal: false, vertical: true)
                .gridProbe("input-midi-event", area: "input-midi-body")
            if data.midiLosses > 0 { status("MIDI resets or losses: \(data.midiLosses)", error: true) }
        }.gridArea("input-midi-body", inset: 0)
    }
    private var selectedDevice: AudioDevice? { data.audioDevices.first { $0.id == inputs.audioID } }
    private var channelChoices: [AudioChannels] { AudioChannels.choices(count: selectedDevice?.channels ?? 0) }
    private func level(_ value: Double) -> Double? { data.audio.ready ? value : nil }
    private func decibels(_ value: Double) -> String {
        guard data.audio.ready else { return "—" }
        return value > 0 ? String(format: "%.1f dBFS", 20 * log10(value)) : "−∞ dBFS"
    }
    private func normalized(_ title: String, _ value: Double) -> some View {
        SignalMeter(title, reading: data.audio.ready ? String(format: "%.2f", value) : "—", level: level(value))
    }
    private func status(_ text: String, error: Bool) -> some View {
        Label(text, systemImage: error ? KitIcon.warning.rawValue : "waveform")
            .font(KitType.meta).foregroundStyle(error ? Ink.warning : Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func isProblem(_ status: InputStatus) -> Bool {
        switch status { case .unavailable, .denied, .restricted, .invalidChannels, .failed: true; default: false }
    }
    private var audioStatus: String {
        if inputs.usesSystemAudio {
            switch data.systemStatus {
            case .off: return "System audio off"
            case .picking: return "Choose content in the macOS sharing picker."
            case .starting: return "Starting system audio…"
            case .capturing:
                return !data.audio.ready ? "Waiting for system audio" : data.audioStatus == .silent ? "Silent — receiving system audio" : "Listening to shared system audio"
            case .cancelled: return "Sharing cancelled. Choose Audio to Share to try again."
            case .denied: return "System audio access denied. Choose Audio to Share to request access again."
            case .ended: return "Sharing ended. Choose Audio to Share to start again."
            case .stopping: return "Stopping system audio…"
            case .failed: return "Unable to capture system audio. Choose Audio to Share to try again."
            }
        }
        if inputs.requestingAccess { return "Requesting microphone access…" }
        switch data.audioStatus {
        case .off: return "Audio off"
        case .waiting: return "Waiting for samples"
        case .active: return "Listening"
        case .silent: return "Silent — receiving samples"
        case .unavailable: return "Input unavailable. Reconnect it or choose another input."
        case .denied: return "Microphone access required. Allow VHS in Settings, then start audio."
        case .restricted: return "Microphone access is restricted on this Mac."
        case .invalidChannels: return "Selected channels unavailable. Choose channels for this input."
        case .failed(let code): return "Unable to capture audio (\(code)). Check the input and start again."
        }
    }
    private var midiStatus: String {
        switch data.midiStatus {
        case .off: return "MIDI off"
        case .waiting: return "Waiting for MIDI"
        case .active: return "Receiving MIDI"
        case .unavailable: return "Source unavailable. Reconnect it or choose another source."
        default: return "Unable to receive MIDI. Choose a source and start again."
        }
    }
    private var eventDescription: String {
        guard let event = data.lastMIDI else { return "No MIDI event" }
        let name: String
        switch event.kind {
        case .noteOn: name = "Note on \(event.number)"
        case .noteOff: name = "Note off \(event.number)"
        case .controller: name = "CC \(event.number)"
        case .reset: return "MIDI reset"
        }
        return "\(name) · Channel \(event.channel) · \(Int((event.value * 127).rounded())) / 127"
    }
}
