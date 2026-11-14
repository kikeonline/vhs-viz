import Testing
import Foundation
import CoreMedia
import AudioToolbox
import VHSSystemIO
import VHSRealtime
import VHSInput
import VHSDevices

private func pcmBuffer(frames: Int = 2048, channels: Int = 2, planar: Bool = true,
                       rate: Double = 48_000, time: CMTime? = nil, float: Bool = true) throws -> CMSampleBuffer {
    var format = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: (float ? kAudioFormatFlagsNativeFloatPacked : kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked) | (planar ? kAudioFormatFlagIsNonInterleaved : 0),
        mBytesPerPacket: UInt32((planar ? 1 : channels) * 4), mFramesPerPacket: 1,
        mBytesPerFrame: UInt32((planar ? 1 : channels) * 4), mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 32, mReserved: 0)
    var description: CMAudioFormatDescription?
    #expect(CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &format, layoutSize: 0, layout: nil,
        magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &description) == noErr)
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(rate)),
        presentationTimeStamp: time ?? CMTime(value: 100, timescale: Int32(rate)), decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    #expect(CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil,
        refcon: nil, formatDescription: description, sampleCount: frames, sampleTimingEntryCount: 1,
        sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample) == noErr)
    let output = try #require(sample)
    var data = [Float](repeating: 0, count: frames * channels)
    for frame in 0..<frames {
        for channel in 0..<channels {
            let tone = Float(0.5 * sin(2 * .pi * 32 * Double(frame) / 2048)) * (channel == 0 ? 1 : -1)
            data[planar ? channel * frames + frame : frame * channels + channel] = tone
        }
    }
    let list = AudioBufferList.allocate(maximumBuffers: planar ? channels : 1)
    defer { list.unsafeMutablePointer.deallocate() }
    let status = data.withUnsafeMutableBufferPointer { values in
        for channel in 0..<list.count {
            list[channel] = AudioBuffer(mNumberChannels: UInt32(planar ? 1 : channels),
                mDataByteSize: UInt32((planar ? frames : frames * channels) * 4),
                mData: values.baseAddress! + (planar ? channel * frames : 0))
        }
        return CMSampleBufferSetDataBufferFromAudioBufferList(output, blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: list.unsafePointer)
    }
    #expect(status == noErr)
    #expect(CMSampleBufferSetDataReady(output) == noErr)
    return output
}

@Suite(.serialized) struct SystemAudioTests {
    @Test(arguments: [true, false]) func nativePCMMatchesSharedEngine(_ planar: Bool) throws {
        let receiver = try #require(vhs_system_receiver_create()); defer { vhs_system_receiver_release(receiver) }
        let sample = try pcmBuffer(planar: planar)
        vhs_system_receiver_enable(receiver, 1)
        vhs_system_receiver_output(receiver, sample, 1) // SCStreamOutputTypeAudio
        #expect(vhs_system_receiver_error(receiver) == 0, "PCM status: \(vhs_system_receiver_error(receiver)), planar: \(planar)")
        let analyzer = try AudioAnalyzer()
        try analyzer.drain(vhs_system_receiver_queue(receiver)!)
        #expect(analyzer.signals.ready && analyzer.signals.endSampleTime == 2148)
        #expect(abs(analyzer.signals.rms - 0.5 / sqrt(2)) < 1e-5)
        #expect(abs(analyzer.signals.mid - 0.5 / sqrt(2)) < 1e-5)
    }
    @Test func ignoredVideoAndDisabledReceiverDoNotTouchSamples() throws {
        let receiver = try #require(vhs_system_receiver_create()); defer { vhs_system_receiver_release(receiver) }
        let sample = try pcmBuffer()
        vhs_system_receiver_output(receiver, sample, 1)
        vhs_system_receiver_enable(receiver, 1)
        vhs_system_receiver_output(receiver, nil, 0) // Defensive video path: no sample inspection.
        vhs_system_receiver_output(receiver, nil, 2) // No microphone capture.
        var chunk = VHSAudioChunk()
        #expect(vhs_audio_pop(vhs_system_receiver_queue(receiver), &chunk) == 0)
        #expect(vhs_system_receiver_error(receiver) == 0)
        vhs_system_receiver_enable(receiver, 0)
        vhs_system_receiver_output(receiver, sample, 1)
        #expect(vhs_audio_pop(vhs_system_receiver_queue(receiver), &chunk) == 0)
    }
    @Test func malformedPCMAndTimelineAreRejected() throws {
        var untyped: CMSampleBuffer?
        #expect(CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: true,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: nil, sampleCount: 0,
            sampleTimingEntryCount: 0, sampleTimingArray: nil, sampleSizeEntryCount: 0,
            sampleSizeArray: nil, sampleBufferOut: &untyped) == noErr)
        let samples: [CMSampleBuffer?] = [try pcmBuffer(float: false), try pcmBuffer(channels: 3),
                       try pcmBuffer(time: .invalid), try pcmBuffer(frames: 8193), untyped, nil]
        for sample in samples {
            let receiver = try #require(vhs_system_receiver_create()); defer { vhs_system_receiver_release(receiver) }
            vhs_system_receiver_enable(receiver, 1)
            vhs_system_receiver_output(receiver, sample, 1)
            #expect(vhs_system_receiver_error(receiver) != 0)
            var chunk = VHSAudioChunk()
            #expect(vhs_audio_pop(vhs_system_receiver_queue(receiver), &chunk) == 0)
        }
    }
    @Test func irregularMonoBuffersOverflowAndRateChangesRecover() throws {
        let receiver = try #require(vhs_system_receiver_create()); defer { vhs_system_receiver_release(receiver) }
        vhs_system_receiver_enable(receiver, 1)
        let queue = vhs_system_receiver_queue(receiver)!
        for i in 0..<64 {
            vhs_system_receiver_output(receiver, try pcmBuffer(frames: 257, channels: 1, rate: 44_100, time: CMTime(value: Int64(i * 257), timescale: 44_100)), 1)
        }
        vhs_system_receiver_output(receiver, try pcmBuffer(frames: 257, channels: 1, rate: 44_100), 1)
        #expect(vhs_audio_dropped(queue) == 1 && vhs_system_receiver_error(receiver) == 0, "drops: \(vhs_audio_dropped(queue)), status: \(vhs_system_receiver_error(receiver))")
        let a = try AudioAnalyzer(); try a.drain(queue)
        #expect(!a.signals.ready)
        vhs_system_receiver_output(receiver, try pcmBuffer(frames: 4096, channels: 1, rate: 96_000), 1)
        try a.drain(queue)
        #expect(a.signals.ready && a.signals.sampleRate == 96_000)
    }
    @Test func nativeIdleStopHasNoPickerAndQueuesAreIndependent() async throws {
        let a = try #require(vhs_system_create()), b = try #require(vhs_system_create())
        defer { vhs_system_release(a); vhs_system_release(b) }
        #expect(vhs_system_state(a) == 0 && vhs_system_state(b) == 0)
        #expect(vhs_system_queue(a) != vhs_system_queue(b))
        // Both calls complete before the main queue can process the presentation.
        // Generation cancellation must reject it before any picker is instantiated.
        let address = UInt(bitPattern: a)
        await MainActor.run {
            let handle = UnsafeMutableRawPointer(bitPattern: address)!
            vhs_system_present(handle)
            vhs_system_stop(handle)
            #expect(vhs_system_state(handle) == 8)
        }
        for _ in 0..<100 {
            if vhs_system_state(a) == 0 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(vhs_system_state(a) == 0 && vhs_system_state(b) == 0)
    }
    @Test func staleCrossSourceConfigurationCannotOpenPicker() async throws {
        let service = InputService()
        await service.configureSystemAudio(enabled: false, revision: 3)
        await service.configureSystemAudio(enabled: true, revision: 2)
        await service.configureAudio(id: "old", channels: AudioChannels(), enabled: true, revision: 1)
        let snapshot = await service.poll()
        #expect(snapshot.systemStatus == .off && snapshot.audioStatus == .off && snapshot.audioRevision == 3)
        await service.shutdown()
        await service.configureSystemAudio(enabled: true, revision: 100)
        #expect(await service.poll().systemStatus == .off)
    }
    @Test func systemTerminalPolicyRequiresExplicitNewRequest() {
        #expect(SystemAudioStatus.allCases.count == 9)
        for status in [SystemAudioStatus.cancelled, .denied, .failed, .ended, .off] { #expect(status.isTerminal) }
        for status in [SystemAudioStatus.picking, .starting, .capturing, .stopping] { #expect(!status.isTerminal) }
        #expect(AudioInputSource.system != AudioInputSource.device("system"))
    }
}
