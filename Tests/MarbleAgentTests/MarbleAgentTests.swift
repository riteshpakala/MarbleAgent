import Foundation
import GraniteAgents
import Metal
import XCTest
@testable import MarbleAgent

/// Marble is found the way an app finds it, its schema is what a model is shown, and a call gives a photo
/// its look on the GPU and writes it where it says.
final class MarbleAgentTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("marble-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Fixture.quadrants(at: folder.appendingPathComponent("quad.png"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func call(_ input: [String: Any]) async throws -> MarbleResult {
        let data = try JSONSerialization.data(withJSONObject: input)
        let answer = try await AnyAgentPackage(MarbleAgent.self).perform(data)
        return try JSONDecoder().decode(MarbleResult.self, from: answer)
    }

    private func assertNear(_ got: [Int], _ want: [Int], _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(zip(got, want).allSatisfy { abs($0 - $1) <= 1 }, "\(what): \(got), wanted \(want)", file: file, line: line)
    }

    func testTheRecordIsFoundWithNothingListed() throws {
        let marble = try XCTUnwrap(GraniteRoster.discovered().package("marble"))
        XCTAssertEqual(marble.module, "MarbleAgent")
        XCTAssertEqual(marble.summary, MarbleAgent.summary)
    }

    func testTheSchemaIsWhatAModelIsShown() {
        let marble = AnyAgentPackage(MarbleAgent.self)
        XCTAssertEqual(marble.schema, .object([
            .init(name: "path", schema: .string, required: true),
            .init(name: "filter", schema: .choice(["sepia"]), required: false),
            .init(name: "intensity", schema: .number, required: false),
            .init(name: "output", schema: .string, required: false),
            .init(name: "directory", schema: .string, required: false),
        ]))
        XCTAssertTrue(marble.takesDirectory, "the host fills the folder it works in")
    }

    func testSepiaTonesThePhotoAndWritesItBeside() async throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "no Metal device")
        let result = try await call(["path": "quad.png", "directory": folder.path])
        XCTAssertEqual(URL(fileURLWithPath: result.path).lastPathComponent, "quad-sepia.png")
        XCTAssertEqual([result.width, result.height], [64, 64])
        XCTAssertEqual(result.filter, .sepia)
        let pixels = try Fixture.pixels(of: URL(fileURLWithPath: result.path))
        assertNear(pixels.at(16, 16), [255, 255, 239], "white, warmed")
        assertNear(pixels.at(48, 16), [0, 0, 0], "black stays black")
        assertNear(pixels.at(16, 48), [100, 89, 69], "red, browned")
        assertNear(pixels.at(48, 48), [173, 154, 120], "gray, toned")
    }

    func testIntensityZeroLeavesThePhotoAsItWas() async throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "no Metal device")
        let result = try await call(["path": "quad.png", "directory": folder.path, "intensity": 0, "output": "plain/quad.png"])
        XCTAssertEqual(result.path, folder.appendingPathComponent("plain/quad.png").standardizedFileURL.path, "written where it was asked, its folder made")
        let pixels = try Fixture.pixels(of: URL(fileURLWithPath: result.path))
        assertNear(pixels.at(16, 16), [255, 255, 255], "white")
        assertNear(pixels.at(16, 48), [255, 0, 0], "red")
    }

    func testAPhotoThatIsNotThereSaysWhere() async throws {
        do {
            _ = try await call(["path": "missing.png", "directory": folder.path])
            XCTFail("a call on a missing photo answered")
        } catch {
            XCTAssertTrue("\(error)".contains("missing.png"), "\(error)")
        }
    }
}
