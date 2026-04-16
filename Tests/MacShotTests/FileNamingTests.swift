import XCTest
@testable import MacShot

final class FileNamingTests: XCTestCase {

    // MARK: - Extension Correctness

    func testPNGFilenameExtension() {
        let filename = FileNamingManager.generateFilename(format: .png)
        XCTAssertTrue(filename.hasSuffix(".png"), "PNG filename should end with .png, got: \(filename)")
    }

    func testJPEGFilenameExtension() {
        let filename = FileNamingManager.generateFilename(format: .jpeg)
        XCTAssertTrue(filename.hasSuffix(".jpeg"), "JPEG filename should end with .jpeg, got: \(filename)")
    }

    func testTIFFFilenameExtension() {
        let filename = FileNamingManager.generateFilename(format: .tiff)
        XCTAssertTrue(filename.hasSuffix(".tiff"), "TIFF filename should end with .tiff, got: \(filename)")
    }

    // MARK: - Filename Structure

    func testDefaultFilenameContainsMacShot() {
        let filename = FileNamingManager.defaultFilename(format: .png)
        XCTAssertTrue(filename.contains("MacShot"), "Default filename should contain 'MacShot', got: \(filename)")
    }

    func testFilenameContainsDate() {
        let filename = FileNamingManager.generateFilename(format: .png)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        XCTAssertTrue(filename.contains(todayString), "Filename should contain today's date, got: \(filename)")
    }

    func testFilenameIsNotEmpty() {
        let filename = FileNamingManager.generateFilename(format: .png)
        XCTAssertFalse(filename.isEmpty)
    }

    func testDefaultFilenameMatchesGenerateFilename() {
        let default1 = FileNamingManager.defaultFilename(format: .png)
        let generated = FileNamingManager.generateFilename(format: .png, pattern: nil)
        // Both should produce "MacShot" prefix with the same format
        XCTAssertTrue(default1.hasPrefix("MacShot"))
        XCTAssertTrue(generated.hasPrefix("MacShot"))
        XCTAssertTrue(default1.hasSuffix(".png"))
        XCTAssertTrue(generated.hasSuffix(".png"))
    }

    // MARK: - Invalid Characters

    func testFilenameDoesNotContainSlashes() {
        let filename = FileNamingManager.generateFilename(format: .png, pattern: "Test/Name {date}")
        XCTAssertFalse(filename.contains("/"), "Filename should not contain '/', got: \(filename)")
        XCTAssertFalse(filename.contains("\\"), "Filename should not contain '\\', got: \(filename)")
    }

    func testFilenameDoesNotContainColons() {
        let filename = FileNamingManager.generateFilename(format: .png, pattern: "Test:Name {date}")
        XCTAssertFalse(filename.contains(":"), "Filename should not contain ':', got: \(filename)")
    }

    func testFilenameDoesNotContainQuestionMark() {
        let filename = FileNamingManager.generateFilename(format: .png, pattern: "Test? {date}")
        XCTAssertFalse(filename.contains("?"), "Filename should not contain '?', got: \(filename)")
    }

    func testFilenameDoesNotContainQuotes() {
        let filename = FileNamingManager.generateFilename(format: .png, pattern: "Test\"Name {date}")
        XCTAssertFalse(filename.contains("\""), "Filename should not contain '\"', got: \(filename)")
    }

    func testFilenameDoesNotContainAngleBrackets() {
        let filename = FileNamingManager.generateFilename(format: .png, pattern: "Test<>Name {date}")
        XCTAssertFalse(filename.contains("<"), "Filename should not contain '<', got: \(filename)")
        XCTAssertFalse(filename.contains(">"), "Filename should not contain '>', got: \(filename)")
    }

    func testFilenameDoesNotContainPipe() {
        let filename = FileNamingManager.generateFilename(format: .png, pattern: "Test|Name {date}")
        XCTAssertFalse(filename.contains("|"), "Filename should not contain '|', got: \(filename)")
    }

    func testFilenameDoesNotContainAsterisk() {
        let filename = FileNamingManager.generateFilename(format: .png, pattern: "Test*Name {date}")
        XCTAssertFalse(filename.contains("*"), "Filename should not contain '*', got: \(filename)")
    }

    // MARK: - Custom Pattern

    func testCustomPatternReplacesTokens() {
        let filename = FileNamingManager.generateFilename(format: .png, pattern: "Screenshot {date} at {time}")
        XCTAssertTrue(filename.hasPrefix("Screenshot "), "Custom pattern should be applied, got: \(filename)")
        XCTAssertFalse(filename.contains("{date}"), "Token {date} should be replaced")
        XCTAssertFalse(filename.contains("{time}"), "Token {time} should be replaced")
    }

    // MARK: - File Extension

    func testImageFormatFileExtensions() {
        XCTAssertEqual(ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageFormat.jpeg.fileExtension, "jpeg")
        XCTAssertEqual(ImageFormat.tiff.fileExtension, "tiff")
    }
}
