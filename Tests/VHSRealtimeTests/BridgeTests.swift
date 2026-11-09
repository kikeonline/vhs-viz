import Testing
import VHSRealtime

@Test func boundedQueuePreservesOrderAndRejectsOverflow() throws {
    let bridge = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(bridge) }
    for i in 0..<256 {
        var input = VHSInput(); input.kind = 1; input.offset = Int32(i); input.sampleTime = 12345
        #expect(vhs_bridge_push(bridge, input) == 1)
    }
    #expect(vhs_bridge_push(bridge, VHSInput()) == 0)
    #expect(vhs_bridge_dropped(bridge) == 1)
    for i in 0..<256 {
        var input = VHSInput()
        #expect(vhs_bridge_pop(bridge, &input) == 1)
        #expect(input.offset == i)
        #expect(input.sampleTime == 12345)
    }
    var input = VHSInput()
    #expect(vhs_bridge_pop(bridge, &input) == 0)
    #expect(vhs_bridge_push(bridge, input) == 1)
    #expect(vhs_bridge_pop(bridge, &input) == 1)
}
@Test func bridgeValuesAndInstanceIsolation() throws {
    let a = try #require(vhs_bridge_create()), b = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(a); vhs_bridge_release(b) }
    vhs_bridge_set(a, 0, 0.9)
    #expect(vhs_bridge_get(a, 0) == 0.9)
    #expect(vhs_bridge_get(b, 0) == 0.24)
    for invalid in [Double.nan, .infinity, -1, 2] { vhs_bridge_set(a, 0, invalid) }
    #expect(vhs_bridge_get(a, 0) == 0.9)
    vhs_bridge_retain(a); vhs_bridge_release(a)
    #expect(vhs_bridge_get(a, 0) == 0.9)
}

@Test func concurrentProducerConsumerKeepsEventPayloads() async throws {
    let bridge = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(bridge) }
    let address = UInt(bitPattern: bridge)
    let writer = Task.detached {
        let pointer = OpaquePointer(bitPattern: address)!
        for i in 0..<20_000 {
            var event = VHSInput(); event.offset = Int32(i); event.sampleTime = Int64(i) * 512
            while vhs_bridge_push(pointer, event) == 0 { await Task.yield() }
        }
    }
    for i in 0..<20_000 {
        var event = VHSInput()
        while vhs_bridge_pop(bridge, &event) == 0 { await Task.yield() }
        #expect(event.offset == i)
        #expect(event.sampleTime == Int64(i) * 512)
    }
    await writer.value
}
