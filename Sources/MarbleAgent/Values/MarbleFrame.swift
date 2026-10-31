/// What a marble run says as it goes: the photo read, the look given on the GPU, the result written.
public enum MarbleFrame: Sendable, Equatable {
    case read(path: String, width: Int, height: Int)
    case filtered(MarbleFilter, milliseconds: Int)
    case written(MarbleResult)

    /// The result, once it is written.
    public var result: MarbleResult? {
        if case .written(let result) = self { return result }
        return nil
    }
}
