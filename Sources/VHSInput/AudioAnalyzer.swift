import Accelerate
import Foundation
import VHSRealtime

public enum InputEngineError: Error { case transformUnavailable, invalidChannel }

/// Transient values only. Full-scale sine RMS is 1/sqrt(2); all exposed signals are 0...1.
public struct AudioSignals: Sendable, Equatable {
    public var rms = 0.0, peak = 0.0, low = 0.0, mid = 0.0, high = 0.0, transient = 0.0
    public var clipped = false, ready = false
    public var invalidSamples = 0
    public var sampleRate = 48_000.0
    public var windowFrames = 2048
    public var endSampleTime: Int64 = 0
    public var windowDuration: Double { Double(windowFrames) / sampleRate }
    public init() {}
}

/// Single worker ownership. Never invoke on an audio callback or share concurrently.
/// The C queue alone crosses producer/consumer threads; this class owns DSP storage.
public final class AudioAnalyzer {
    public private(set) var signals = AudioSignals()
    private var spectrum: Spectrum
    private var ring: [Double]
    private var invalid: [Int]
    private var channels = 1, position = 0, filled = 0, sinceHop = 0
    private var expectedTime: Int64?
    private var generation: UInt32?
    private var previousRMS = 0.0

    public init() throws {
        spectrum = try Spectrum(count: 2048)
        ring = .init(repeating: 0, count: 4096)
        invalid = .init(repeating: 0, count: 2048)
    }

    public func reset() {
        ring = .init(repeating: 0, count: spectrum.count * 2)
        invalid = .init(repeating: 0, count: spectrum.count)
        position = 0; filled = 0; sinceHop = 0; previousRMS = 0; expectedTime = nil
        let rate = signals.sampleRate
        signals = AudioSignals(); signals.sampleRate = rate; signals.windowFrames = spectrum.count
    }

    /// Bounded to one queue capacity even if a producer keeps publishing during this call.
    @discardableResult public func drain(_ queue: OpaquePointer) throws -> Int {
        let epoch = vhs_audio_generation(queue)
        if generation != epoch { reset(); generation = epoch }
        var chunk = VHSAudioChunk(), consumed = 0
        for _ in 0..<VHS_INPUT_QUEUE_SLOTS {
            guard vhs_audio_pop(queue, &chunk) != 0 else { break }
            consumed += 1
            // Discard samples from before a loss/reset. Do not replay stale levels after a gap.
            guard chunk.generation == epoch else { continue }
            try accept(&chunk)
        }
        let after = vhs_audio_generation(queue)
        if after != epoch { reset(); generation = after }
        return consumed
    }

    private func accept(_ chunk: inout VHSAudioChunk) throws {
        let rate = chunk.sampleRate, channelCount = Int(chunk.channels)
        if signals.sampleRate != rate || channels != channelCount || expectedTime != chunk.sampleTime {
            let size = Self.windowSize(rate)
            if spectrum.count != size { spectrum = try Spectrum(count: size) }
            channels = channelCount; signals.sampleRate = rate
            reset()
        }
        let frames = Int(chunk.frames)
        withUnsafeBytes(of: &chunk.samples) { bytes in
            let samples = bytes.bindMemory(to: Float.self)
            for frame in 0..<frames {
                var bad = 0
                for channel in 0..<channels {
                    let value = Double(samples[frame * channels + channel])
                    if !value.isFinite { bad += 1 }
                    ring[position * 2 + channel] = value.isFinite ? min(8, max(-8, value)) : 0
                }
                invalid[position] = bad
                position = (position + 1) % spectrum.count
                filled = min(spectrum.count, filled + 1); sinceHop += 1
                if filled == spectrum.count && sinceHop >= spectrum.count / 4 {
                    analyze(endTime: chunk.sampleTime + Int64(frame) + 1)
                    sinceHop = 0
                }
            }
        }
        expectedTime = chunk.sampleTime + Int64(frames)
    }

    public static func windowSize(_ rate: Double) -> Int {
        // Nearest power of two to 46.44 ms, bounded 512...8192 for supported rates.
        let exponent = Int(log2(min(192_000, max(8_000, rate)) * 2048 / 44_100).rounded())
        return 1 << min(13, max(9, exponent))
    }

    private func analyze(endTime: Int64) {
        let n = spectrum.count
        var power = 0.0, peak = 0.0, bad = 0
        var bands = [Double](repeating: 0, count: 3)
        for i in 0..<n {
            let index = (position + i) % n
            bad += invalid[index]
            for channel in 0..<channels {
                let value = ring[index * 2 + channel]
                power += value * value; peak = max(peak, abs(value))
            }
        }
        for channel in 0..<channels {
            var mean = 0.0
            for i in 0..<n { mean += ring[((position + i) % n) * 2 + channel] }
            mean /= Double(n)
            for i in 0..<n {
                spectrum.real[i] = (ring[((position + i) % n) * 2 + channel] - mean) * spectrum.window[i]
            }
            spectrum.execute()
            for bin in 1...n / 2 {
                let frequency = Double(bin) * signals.sampleRate / Double(n)
                guard frequency >= 20 else { continue }
                let band = frequency < 250 ? 0 : (frequency < 2000 ? 1 : 2)
                let re = spectrum.outReal[bin], im = spectrum.outImaginary[bin]
                let symmetry = bin == n / 2 ? 1.0 : 2.0
                bands[band] += symmetry * (re * re + im * im) / (Double(n) * spectrum.windowPower * Double(channels))
            }
        }
        let rms = sqrt(power / Double(n * channels))
        signals.rms = min(1, rms); signals.peak = min(1, peak)
        signals.low = min(1, sqrt(bands[0])); signals.mid = min(1, sqrt(bands[1])); signals.high = min(1, sqrt(bands[2]))
        signals.transient = min(1, max(0, (rms - previousRMS - 0.02) / 0.25))
        signals.clipped = peak > 1; signals.invalidSamples = bad; signals.ready = true
        signals.endSampleTime = endTime; previousRMS = rms
    }
}

private final class Spectrum {
    let count: Int
    let setup: vDSP_DFT_SetupD
    let window: [Double], windowPower: Double
    var real: [Double], imaginary: [Double], outReal: [Double], outImaginary: [Double]
    init(count: Int) throws {
        guard let setup = vDSP_DFT_zop_CreateSetupD(nil, vDSP_Length(count), .FORWARD) else {
            throw InputEngineError.transformUnavailable
        }
        self.count = count; self.setup = setup
        window = (0..<count).map { 0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(count)) }
        windowPower = window.reduce(0) { $0 + $1 * $1 }
        real = .init(repeating: 0, count: count); imaginary = real; outReal = real; outImaginary = real
    }
    deinit { vDSP_DFT_DestroySetupD(setup) }
    func execute() { vDSP_DFT_ExecuteD(setup, real, imaginary, &outReal, &outImaginary) }
}
