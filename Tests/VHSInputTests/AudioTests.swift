import Foundation
import Testing
import VHSInput
import VHSRealtime

private func tone(_ frames: Int, rate: Double = 48_000, frequency: Double = 750, amplitude: Double = 0.5) -> [Float] {
    (0..<frames).map { Float(amplitude * sin(2 * .pi * frequency * Double($0) / rate)) }
}

private func feed(_ samples: [Float], analyzer: AudioAnalyzer, queue: OpaquePointer,
                  channels: Int = 1, rate: Double = 48_000, blocks: [Int] = [512], start: Int64 = 0) throws {
    var frame = 0, block = 0
    while frame < samples.count / channels {
        let size = min(blocks[block % blocks.count], samples.count / channels - frame)
        let accepted = samples.withUnsafeBufferPointer {
            vhs_audio_push_interleaved(queue, $0.baseAddress! + frame * channels, UInt32(size), UInt32(channels), rate, start + Int64(frame))
        }
        #expect(accepted == 1)
        try analyzer.drain(queue)
        frame += size; block += 1
    }
}

@Test func silenceWarmupAndWindowTiming() throws {
    let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
    let analyzer = try AudioAnalyzer()
    try feed([Float](repeating: 0, count: 2047), analyzer: analyzer, queue: q)
    #expect(!analyzer.signals.ready)
    try feed([0], analyzer: analyzer, queue: q, start: 2047)
    let s = analyzer.signals
    #expect(s.ready && s.endSampleTime == 2048 && s.windowFrames == 2048)
    #expect(s.rms == 0 && s.peak == 0 && s.low == 0 && s.mid == 0 && s.high == 0 && s.transient == 0)
    #expect(abs(s.windowDuration - 2048.0 / 48_000) < 1e-12)
}

@Test(arguments: [8_000.0, 22_050, 44_100, 48_000, 96_000, 192_000])
func calibratedTonesAdaptToSampleRate(_ rate: Double) throws {
    let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
    let a = try AudioAnalyzer(), n = AudioAnalyzer.windowSize(rate)
    let frequency = rate / Double(n) * 32
    try feed(tone(n * 3, rate: rate, frequency: frequency), analyzer: a, queue: q, rate: rate, blocks: [1, 17, 256, 777])
    #expect(abs(a.signals.rms - 0.5 / sqrt(2)) < 0.00001)
    #expect(abs(a.signals.peak - 0.5) < 0.00001)
    #expect(abs(a.signals.mid - 0.5 / sqrt(2)) < 0.00001)
    #expect(a.signals.low < 0.00001 && a.signals.high < 0.00001)
    #expect((0.02...0.065).contains(a.signals.windowDuration))
}

@Test(arguments: [(93.75, 0), (750.0, 1), (6000.0, 2)])
func separatedFrequencyBands(_ fixture: (Double, Int)) throws {
    let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
    let a = try AudioAnalyzer()
    try feed(tone(4096, frequency: fixture.0), analyzer: a, queue: q)
    let bands = [a.signals.low, a.signals.mid, a.signals.high]
    for i in 0..<3 { #expect(abs(bands[i] - (i == fixture.1 ? 0.5 / sqrt(2) : 0)) < 0.00001) }
}

@Test func stereoDoesNotCancelAndLayoutsAgree() throws {
    let q = try #require(vhs_audio_queue_create()), p = try #require(vhs_audio_queue_create())
    defer { vhs_audio_queue_destroy(q); vhs_audio_queue_destroy(p) }
    let a = try AudioAnalyzer(), b = try AudioAnalyzer()
    let left = tone(8192), right = left.map { -$0 }
    let interleaved = zip(left, right).flatMap { [$0.0, $0.1] }
    try feed(interleaved, analyzer: a, queue: q, channels: 2, blocks: [7, 1024, 257])
    let ok = left.withUnsafeBufferPointer { l in right.withUnsafeBufferPointer { r in
        vhs_audio_push_planar(p, l.baseAddress, r.baseAddress, 8192, 48_000, 0)
    } }
    #expect(ok == 1); try b.drain(p)
    #expect(a.signals == b.signals)
    #expect(abs(a.signals.rms - 0.5 / sqrt(2)) < 0.00001)
    #expect(abs(a.signals.mid - 0.5 / sqrt(2)) < 0.00001)
    // A silent second channel halves power, not amplitude, with peak unchanged.
    let stereo = left.flatMap { [$0, Float(0)] }
    try feed(stereo, analyzer: a, queue: q, channels: 2, start: 8192)
    #expect(abs(a.signals.rms - 0.25) < 0.00001)
    #expect(abs(a.signals.mid - 0.25) < 0.00001 && abs(a.signals.peak - 0.5) < 0.00001)
}

@Test func impulsesAndOnsetRecoverToSilence() throws {
    let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
    let a = try AudioAnalyzer()
    var impulse = [Float](repeating: 0, count: 2048); impulse[1024] = 1
    try feed(impulse, analyzer: a, queue: q)
    #expect(abs(a.signals.rms - 1 / sqrt(2048)) < 0.00001 && a.signals.peak == 1)
    try feed([Float](repeating: 0, count: 2048), analyzer: a, queue: q, start: 2048)
    #expect(a.signals.rms == 0 && a.signals.peak == 0)
    try feed([Float](repeating: 0.8, count: 512), analyzer: a, queue: q, start: 4096)
    #expect(a.signals.transient == 1)
    try feed([Float](repeating: 0.8, count: 4096), analyzer: a, queue: q, start: 4608)
    #expect(a.signals.transient == 0)
}

@Test func invalidSamplesClippingAndDCStayFinite() throws {
    let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
    let a = try AudioAnalyzer()
    var samples = [Float](repeating: 2, count: 2048)
    samples[0] = .nan; samples[1] = .infinity; samples[2] = -.infinity; samples[3] = .greatestFiniteMagnitude
    try feed(samples, analyzer: a, queue: q)
    #expect(a.signals.invalidSamples == 3 && a.signals.clipped)
    for value in [a.signals.rms, a.signals.peak, a.signals.low, a.signals.mid, a.signals.high, a.signals.transient] {
        #expect(value.isFinite && (0...1).contains(value))
    }
    try feed([Float](repeating: 0.4, count: 4096), analyzer: a, queue: q, start: 2048)
    #expect(!a.signals.clipped && a.signals.invalidSamples == 0)
    #expect(abs(a.signals.rms - 0.4) < 1e-7 && a.signals.low < 1e-7 && a.signals.mid < 1e-7 && a.signals.high < 1e-7)
}

@Test func formatTimelineAndDisconnectResetWarmup() throws {
    let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
    let a = try AudioAnalyzer()
    try feed(tone(2048), analyzer: a, queue: q)
    #expect(a.signals.ready)
    try feed([0], analyzer: a, queue: q, rate: 96_000, start: 2048)
    #expect(!a.signals.ready && a.signals.windowFrames == 4096)
    try feed([Float](repeating: 0, count: 4095), analyzer: a, queue: q, rate: 96_000, start: 2049)
    #expect(a.signals.ready)
    try feed([0], analyzer: a, queue: q, rate: 96_000, start: 42)
    #expect(!a.signals.ready)
    try feed([0, 0], analyzer: a, queue: q, channels: 2, rate: 96_000, start: 43)
    #expect(!a.signals.ready)
    vhs_audio_mark_gap(q); try a.drain(q)
    #expect(!a.signals.ready && a.signals.rms == 0)
}

@Test func wholeBlockOverflowDiscardsStaleAudioAndRecovers() throws {
    let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
    let a = try AudioAnalyzer(), samples = [Float](repeating: 0.5, count: 8192)
    for i in 0..<4 {
        #expect(samples.withUnsafeBufferPointer { vhs_audio_push_interleaved(q, $0.baseAddress, 8192, 1, 48_000, Int64(i * 8192)) } == 1)
    }
    #expect(samples.withUnsafeBufferPointer { vhs_audio_push_interleaved(q, $0.baseAddress, 1, 1, 48_000, 32768) } == 0)
    #expect(vhs_audio_dropped(q) == 1)
    #expect(try a.drain(q) == 64 && !a.signals.ready)
    try feed(tone(4096), analyzer: a, queue: q, start: 32769)
    #expect(a.signals.ready && abs(a.signals.rms - 0.5 / sqrt(2)) < 1e-5)
    // Rejection reserves nothing when a block needs more slots than remain.
    for _ in 0..<63 { #expect(samples.withUnsafeBufferPointer { vhs_audio_push_interleaved(q, $0.baseAddress, 1, 1, 48_000, 0) } == 1) }
    #expect(samples.withUnsafeBufferPointer { vhs_audio_push_interleaved(q, $0.baseAddress, 513, 1, 48_000, 0) } == 0)
    var chunk = VHSAudioChunk(), count = 0
    while vhs_audio_pop(q, &chunk) != 0 { count += 1 }
    #expect(count == 63)
}

@Test func queueRejectsInvalidMetadataWithoutReadingBuffers() throws {
    let q = try #require(vhs_audio_queue_create()); defer { vhs_audio_queue_destroy(q) }
    var value: Float = 0
    for rate in [Double.nan, .infinity, 7999, 192001] {
        #expect(vhs_audio_push_interleaved(q, &value, 1, 1, rate, 0) == 0)
    }
    #expect(vhs_audio_push_interleaved(q, nil, 1, 1, 48_000, 0) == 0)
    #expect(vhs_audio_push_interleaved(q, &value, 8193, 1, 48_000, 0) == 0)
    #expect(vhs_audio_push_interleaved(q, &value, 1, 3, 48_000, 0) == 0)
    #expect(vhs_audio_push_interleaved(q, &value, 1, 1, 48_000, .max) == 0)
    var chunk = VHSAudioChunk()
    #expect(vhs_audio_pop(q, &chunk) == 0)
}

@Test func independentAudioInstancesAndConcurrentQueueWrap() async throws {
    let q = try #require(vhs_audio_queue_create()), other = try #require(vhs_audio_queue_create())
    defer { vhs_audio_queue_destroy(q); vhs_audio_queue_destroy(other) }
    let address = UInt(bitPattern: q)
    let producer = Task.detached {
        let pointer = OpaquePointer(bitPattern: address)!
        for i in 0..<10_000 {
            var sample = Float(i)
            while vhs_audio_push_interleaved(pointer, &sample, 1, 1, 48_000, Int64(i)) == 0 { await Task.yield() }
        }
    }
    var chunk = VHSAudioChunk()
    for i in 0..<10_000 {
        while vhs_audio_pop(q, &chunk) == 0 { await Task.yield() }
        #expect(chunk.sampleTime == Int64(i) && chunk.frames == 1)
        #expect(withUnsafeBytes(of: &chunk.samples) { $0.bindMemory(to: Float.self)[0] } == Float(i))
    }
    await producer.value
    #expect(vhs_audio_pop(other, &chunk) == 0 && vhs_audio_dropped(other) == 0)
    let a = try AudioAnalyzer(), b = try AudioAnalyzer()
    try feed(tone(2048), analyzer: a, queue: q)
    #expect(a.signals.ready && !b.signals.ready)
}
