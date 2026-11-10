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

@Test func documentMailboxBoundsRevisionAndIsolation() throws {
    let a = try #require(vhs_bridge_create()), b = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(a); vhs_bridge_release(b) }
    let original: [UInt8] = [1,2,3,4,5]
    #expect(original.withUnsafeBufferPointer { vhs_bridge_store_document(a,$0.baseAddress,5,1) } == 5)
    #expect(vhs_bridge_document_revision(a) == 1 && vhs_bridge_document_revision(b) == 0)
    var bytes = [UInt8](repeating:0,count:8), origin: UInt32 = 0, revision: UInt32 = 0
    #expect(vhs_bridge_copy_document(a,&bytes,8,&origin,&revision) == 5)
    #expect(Array(bytes.prefix(5)) == original && origin == 1 && revision == 1)
    #expect(vhs_bridge_copy_document(a,&bytes,2,&origin,&revision) == -1)
    #expect(vhs_bridge_store_document(a,nil,UInt32(VHS_STATE_CAPACITY)+1,0) == -1)
    #expect(vhs_bridge_document_revision(a) == 1)
    #expect(vhs_bridge_store_document(a,nil,0,1) == 0)
    #expect(vhs_bridge_copy_document(a,&bytes,8,&origin,&revision) == 0 && revision == 2)
}

@Test func hostRestoreWinsOverUnconsumedEditorPublication() throws {
    let bridge = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(bridge) }
    let editor: [UInt8] = [1,2,3], host: [UInt8] = [9,8,7]
    var revision: UInt32 = 0
    #expect(editor.withUnsafeBufferPointer { vhs_bridge_publish_document(bridge,$0.baseAddress,3,0,&revision) } == 3)
    #expect(revision == 1)
    #expect(host.withUnsafeBufferPointer { vhs_bridge_store_document(bridge,$0.baseAddress,3,1) } == 3)
    #expect(editor.withUnsafeBufferPointer { vhs_bridge_publish_document(bridge,$0.baseAddress,3,revision,&revision) } == -1)
    var bytes = [UInt8](repeating:0,count:3), origin: UInt32 = 0
    #expect(vhs_bridge_copy_document(bridge,&bytes,3,&origin,&revision) == 3)
    #expect(bytes == host && origin == 1 && revision == 2)
    #expect(editor.withUnsafeBufferPointer { vhs_bridge_publish_document(bridge,$0.baseAddress,3,revision,&revision) } == 3)
    #expect(revision == 3)
}
