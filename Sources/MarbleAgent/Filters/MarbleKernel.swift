/// A look's Metal kernel: its function's name and its source, compiled the first time the look is asked for.
/// Every kernel takes the photo as texture 0, writes texture 1, and reads its intensity from buffer 0.
struct MarbleKernel: Sendable {
    let name: String
    let source: String
}
