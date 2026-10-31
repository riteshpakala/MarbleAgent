import Foundation
import Metal

/// The GPU a marble runs on: one device and one queue, and a pipeline per look, compiled from the look's
/// source the first time it is asked for.
///
/// PIN: `@unchecked Sendable` because Metal's devices, queues and pipeline states are safe to use from any
/// thread, and the pipelines made so far are kept under a lock.
public final class MarbleCompute: @unchecked Sendable {
    let device: any MTLDevice
    let queue: any MTLCommandQueue
    private let lock = NSLock()
    private var pipelines: [MarbleFilter: any MTLComputePipelineState] = [:]

    /// This machine's GPU. Made by `MarbleAgent.compute()` on the first call, never before.
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { throw MarbleError.noGPU }
        self.device = device
        self.queue = queue
    }

    /// The look's pipeline, compiled from its source on first use.
    func pipeline(for filter: MarbleFilter) throws -> any MTLComputePipelineState {
        if let made = lock.withLock({ pipelines[filter] }) { return made }
        let kernel = filter.kernel
        let made: any MTLComputePipelineState
        do {
            let library = try device.makeLibrary(source: kernel.source, options: nil)
            guard let function = library.makeFunction(name: kernel.name) else {
                throw MarbleError.shader(filter, "the source has no function named \(kernel.name)")
            }
            made = try device.makeComputePipelineState(function: function)
        } catch let error as MarbleError {
            throw error
        } catch {
            throw MarbleError.shader(filter, "\(error)")
        }
        lock.withLock { pipelines[filter] = made }
        return made
    }

    /// The photo with the look given, at this intensity: one dispatch, a thread a pixel.
    func apply(_ filter: MarbleFilter, intensity: Double, to photo: MarbleImage) async throws -> MarbleImage {
        let pipeline = try pipeline(for: filter)
        // Where the CPU and GPU share memory the result is read in place; elsewhere it is synchronized back.
        let storage: MTLStorageMode = device.hasUnifiedMemory ? .shared : .managed
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: photo.width, height: photo.height, mipmapped: false)
        descriptor.storageMode = storage
        descriptor.usage = [.shaderRead]
        guard let source = device.makeTexture(descriptor: descriptor) else { throw MarbleError.gpu("no texture for the photo") }
        descriptor.usage = [.shaderWrite]
        guard let target = device.makeTexture(descriptor: descriptor) else { throw MarbleError.gpu("no texture for the result") }
        let region = MTLRegionMake2D(0, 0, photo.width, photo.height)
        photo.pixels.withUnsafeBytes { bytes in
            source.replace(region: region, mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: photo.bytesPerRow)
        }

        guard let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeComputeCommandEncoder() else {
            throw MarbleError.gpu("no command buffer")
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(target, index: 1)
        var amount = Float(intensity)
        encoder.setBytes(&amount, length: MemoryLayout<Float>.size, index: 0)
        let width = pipeline.threadExecutionWidth
        let group = MTLSize(width: width, height: max(1, pipeline.maxTotalThreadsPerThreadgroup / width), depth: 1)
        encoder.dispatchThreads(MTLSize(width: photo.width, height: photo.height, depth: 1), threadsPerThreadgroup: group)
        encoder.endEncoding()
        if storage == .managed, let blit = buffer.makeBlitCommandEncoder() {
            blit.synchronize(resource: target)
            blit.endEncoding()
        }
        try await Self.finish(buffer)

        var toned = MarbleImage(width: photo.width, height: photo.height, orientation: photo.orientation)
        let bytesPerRow = toned.bytesPerRow
        toned.pixels.withUnsafeMutableBytes { bytes in
            target.getBytes(bytes.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return toned
    }

    /// Commits the work and returns when the GPU has done it.
    private static func finish(_ buffer: any MTLCommandBuffer) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            buffer.addCompletedHandler { done in
                if let error = done.error { continuation.resume(throwing: MarbleError.gpu("\(error)")) } else { continuation.resume() }
            }
            buffer.commit()
        }
    }
}
