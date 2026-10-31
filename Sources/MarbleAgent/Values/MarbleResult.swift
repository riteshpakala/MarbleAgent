/// What a marble call answers: the file it wrote, its size, the look and how strong, and how long the GPU
/// took.
public struct MarbleResult: Codable, Sendable, Equatable {
    /// The file written, as an absolute path.
    public let path: String
    public let width: Int
    public let height: Int
    public let filter: MarbleFilter
    public let intensity: Double
    /// How long the look took on the GPU, in milliseconds; a look's first call includes compiling its kernel.
    public let milliseconds: Int

    public init(path: String, width: Int, height: Int, filter: MarbleFilter, intensity: Double, milliseconds: Int) {
        self.path = path; self.width = width; self.height = height
        self.filter = filter; self.intensity = intensity; self.milliseconds = milliseconds
    }
}
