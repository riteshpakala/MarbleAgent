//  WHAT: A photo filter on the GPU, as a Granite agent package. A call names a photo and a look from the
//        catalog (`MarbleFilter`); the run reads the photo, gives it the look with the look's Metal kernel,
//        and writes the result beside it; the answer says where.
//  IN:   Input: the photo's path, relative to the folder the host works in; the look (sepia when left out);
//        how strong (0 to 1, full when left out); where to write it (beside the photo when left out).
//  OUT:  MarbleResult: the file written, its size, the look, how strong, and how long the GPU took.
//  PIN:  NOTHING ON THE GPU UNTIL A CALL. The device and queue are made by `compute()` on the first call,
//        and a look's kernel is compiled from its source the first time it is asked for: no metallib
//        ships, and an app that links Marble and never calls it pays nothing.

import Foundation
import GraniteAgents

public struct MarbleAgent: GraniteAgentPackage {
    public struct Input: Codable, Sendable {
        /// The photo, relative to `directory`, or absolute.
        public var path: String
        /// The look, from the catalog; sepia when left out.
        public var filter: MarbleFilter?
        /// How strong, from 0 (the photo as it was) to 1 (the whole look); 1 when left out.
        public var intensity: Double?
        /// Where to write the result, relative to `directory` or absolute; beside the photo, named for the
        /// look, when left out.
        public var output: String?
        /// The folder the host works in.
        public var directory: String?

        public init(path: String, filter: MarbleFilter? = nil, intensity: Double? = nil, output: String? = nil, directory: String? = nil) {
            self.path = path; self.filter = filter; self.intensity = intensity; self.output = output; self.directory = directory
        }
    }

    public typealias Event = MarbleFrame
    public typealias Output = MarbleResult
    public typealias Compute = MarbleCompute

    public static let word = "marble"
    public static let summary = "gives a photo a look from its catalog (sepia) on the GPU and writes the result beside it."
    public static let fields = [
        "path": "the photo to filter, relative to the project",
        "filter": "the look; sepia when left out",
        "intensity": "how strong, from 0 to 1; 1 when left out",
        "output": "where to write the result; beside the photo, named for the look, when left out",
    ]

    public static func compute() async throws -> MarbleCompute { try MarbleCompute() }

    public static func output(from events: [MarbleFrame]) -> MarbleResult? {
        events.compactMap(\.result).last
    }

    public init() {}

    public func run(_ input: Input, context: Context) -> AsyncThrowingStream<MarbleFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let filter = input.filter ?? .sepia
                    let intensity = min(1, max(0, input.intensity ?? 1))
                    let source = Self.resolve(input.path, in: input.directory)
                    let photo = try MarbleImage(contentsOf: source)
                    continuation.yield(.read(path: source.path, width: photo.width, height: photo.height))
                    try Task.checkCancellation()

                    let started = Date()
                    let toned = try await context.compute.apply(filter, intensity: intensity, to: photo)
                    let milliseconds = Int(Date().timeIntervalSince(started) * 1000)
                    continuation.yield(.filtered(filter, milliseconds: milliseconds))
                    try Task.checkCancellation()

                    let target = input.output.map { Self.resolve($0, in: input.directory) } ?? Self.beside(source, filter: filter)
                    try toned.write(to: target)
                    continuation.yield(.written(MarbleResult(path: target.path, width: toned.width, height: toned.height,
                                                             filter: filter, intensity: intensity, milliseconds: milliseconds)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `path`, read from `directory` when it is relative, and from the process's folder when there is none.
    static func resolve(_ path: String, in directory: String?) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") { return URL(fileURLWithPath: expanded).standardizedFileURL }
        let base = directory.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return base.appendingPathComponent(expanded).standardizedFileURL
    }

    /// Beside the photo, named for the look: `beach.jpg` becomes `beach-sepia.jpg`.
    static func beside(_ source: URL, filter: MarbleFilter) -> URL {
        let name = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
        return source.deletingLastPathComponent().appendingPathComponent("\(name)-\(filter.rawValue)").appendingPathExtension(ext)
    }
}
