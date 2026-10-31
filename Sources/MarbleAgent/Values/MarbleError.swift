/// What a marble call can say besides its result.
public enum MarbleError: Error, Equatable, CustomStringConvertible {
    /// This machine has no Metal device.
    case noGPU
    /// The file is not there, or is not an image ImageIO reads.
    case unreadable(String)
    /// The result could not be written there, or its extension names no image format.
    case unwritable(String)
    /// A look's kernel did not compile.
    case shader(MarbleFilter, String)
    /// The GPU refused or failed the work.
    case gpu(String)

    public var description: String {
        switch self {
        case .noGPU: return "this machine has no Metal device"
        case .unreadable(let path): return "no photo could be read at \(path)"
        case .unwritable(let path): return "the result could not be written to \(path); name a .png, .jpg, .heic or .tiff"
        case .shader(let filter, let why): return "the \(filter.rawValue) kernel did not compile: \(why)"
        case .gpu(let why): return "the GPU did not finish: \(why)"
        }
    }
}
