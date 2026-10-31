/// The catalog: every look Marble can give a photo, a case each, each with the Metal kernel that gives it.
/// A new look is a case here and its kernel in a file of its own beside this one, as sepia's is
/// (`MarbleFilter+Sepia.swift`); a model is shown every case.
public enum MarbleFilter: String, Codable, Sendable, CaseIterable {
    /// Warm brown tones, like an old print.
    case sepia

    /// The kernel that gives this look.
    var kernel: MarbleKernel {
        switch self {
        case .sepia: return Self.sepiaKernel
        }
    }
}
