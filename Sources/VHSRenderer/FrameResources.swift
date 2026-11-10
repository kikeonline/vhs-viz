import Foundation
import Metal

/// Completion callbacks run off-main. Every mutable slot and metric is protected
/// by the lock; a checked-out slot is exclusively owned until GPU completion.
final class FrameResources: @unchecked Sendable {
    private struct Slot {
        var busy = false
        var textures: [any MTLTexture] = []
    }
    private let lock = NSLock()
    private var slots = [Slot(), Slot(), Slot()]
    private var allocations = 0
    var metrics: (textures: Int, allocations: Int) {
        lock.lock(); defer { lock.unlock() }
        return (slots.reduce(0) { $0 + $1.textures.count }, allocations)
    }
    func checkout(width: Int? = nil, height: Int? = nil) -> Int? {
        lock.lock(); defer { lock.unlock() }
        let matching = slots.firstIndex { !$0.busy && $0.textures.first?.width == width && $0.textures.first?.height == height }
        let empty = slots.firstIndex { !$0.busy && $0.textures.isEmpty }
        guard let index = matching ?? empty ?? slots.firstIndex(where: { !$0.busy }) else { return nil }
        slots[index].busy = true
        return index
    }
    func release(_ index: Int) {
        lock.lock(); defer { lock.unlock() }
        slots[index].busy = false
    }
    func textures(_ index: Int, device: any MTLDevice, width: Int, height: Int, count: Int = 2) throws -> [any MTLTexture] {
        lock.lock(); defer { lock.unlock() }
        if let first = slots[index].textures.first, first.width == width, first.height == height, slots[index].textures.count >= count { return slots[index].textures }
        // Drop obsolete sizes, never accumulate a cache during resize.
        slots[index].textures = []
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]; descriptor.storageMode = .private
        guard (1...8).contains(count) else { throw RendererError.resourceCreation }
        var textures: [any MTLTexture] = []
        for _ in 0..<count {
            guard let texture = device.makeTexture(descriptor:descriptor) else { throw RendererError.resourceCreation }
            textures.append(texture)
        }
        slots[index].textures = textures; allocations += count
        return slots[index].textures
    }
}
