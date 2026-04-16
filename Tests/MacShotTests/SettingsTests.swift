import XCTest
@testable import MacShot

final class SettingsTests: XCTestCase {

    // MARK: - AppState Defaults

    func testAppStateDefaultSaveDirectory() {
        let state = AppState()
        let expectedDefault = NSSearchPathForDirectoriesInDomains(.picturesDirectory, .userDomainMask, true).first ?? "~/Pictures"
        XCTAssertEqual(state.saveDirectory, expectedDefault)
    }

    func testAppStateDefaultImageFormat() {
        let state = AppState()
        XCTAssertEqual(state.imageFormat, .png)
    }

    func testAppStateDefaultShowOverlay() {
        let state = AppState()
        XCTAssertTrue(state.showOverlayAfterCapture)
    }

    func testAppStateDefaultWindowCaptureBackground() {
        let state = AppState()
        XCTAssertEqual(state.windowCaptureBackground, .wallpaper)
    }

    func testAppStateDefaultWindowCapturePadding() {
        let state = AppState()
        XCTAssertEqual(state.windowCapturePadding, 40.0)
    }

    func testAppStateDefaultJpegQuality() {
        let state = AppState()
        XCTAssertEqual(state.jpegQuality, 0.9)
    }

    func testAppStateDefaultSelfTimerSeconds() {
        let state = AppState()
        XCTAssertEqual(state.selfTimerSeconds, 5)
    }

    func testAppStateDefaultIsCapturing() {
        let state = AppState()
        XCTAssertFalse(state.isCapturing)
    }

    func testAppStateDefaultDesktopIconsHidden() {
        let state = AppState()
        XCTAssertFalse(state.desktopIconsHidden)
    }

    func testAppStateDefaultRecentScreenshots() {
        let state = AppState()
        XCTAssertTrue(state.recentScreenshots.isEmpty)
    }

    // MARK: - ImageFormat Enum

    func testImageFormatCaseCount() {
        XCTAssertEqual(ImageFormat.allCases.count, 3)
    }

    func testImageFormatPNG() {
        XCTAssertEqual(ImageFormat.png.rawValue, "PNG")
    }

    func testImageFormatJPEG() {
        XCTAssertEqual(ImageFormat.jpeg.rawValue, "JPEG")
    }

    func testImageFormatTIFF() {
        XCTAssertEqual(ImageFormat.tiff.rawValue, "TIFF")
    }

    func testImageFormatFromRawValue() {
        XCTAssertEqual(ImageFormat(rawValue: "PNG"), .png)
        XCTAssertEqual(ImageFormat(rawValue: "JPEG"), .jpeg)
        XCTAssertEqual(ImageFormat(rawValue: "TIFF"), .tiff)
        XCTAssertNil(ImageFormat(rawValue: "GIF"))
    }

    // MARK: - WindowCaptureBackground Enum

    func testWindowCaptureBackgroundCaseCount() {
        XCTAssertEqual(WindowCaptureBackground.allCases.count, 3)
    }

    func testWindowCaptureBackgroundWallpaper() {
        XCTAssertEqual(WindowCaptureBackground.wallpaper.rawValue, "Wallpaper")
    }

    func testWindowCaptureBackgroundTransparent() {
        XCTAssertEqual(WindowCaptureBackground.transparent.rawValue, "Transparent")
    }

    func testWindowCaptureBackgroundSolidColor() {
        XCTAssertEqual(WindowCaptureBackground.solidColor.rawValue, "Solid Color")
    }

    func testWindowCaptureBackgroundFromRawValue() {
        XCTAssertEqual(WindowCaptureBackground(rawValue: "Wallpaper"), .wallpaper)
        XCTAssertEqual(WindowCaptureBackground(rawValue: "Transparent"), .transparent)
        XCTAssertEqual(WindowCaptureBackground(rawValue: "Solid Color"), .solidColor)
        XCTAssertNil(WindowCaptureBackground(rawValue: "None"))
    }

    // MARK: - CaptureType Enum

    func testCaptureTypeArea() {
        XCTAssertEqual(CaptureType.area.rawValue, "Area")
    }

    func testCaptureTypeFullscreen() {
        XCTAssertEqual(CaptureType.fullscreen.rawValue, "Fullscreen")
    }

    func testCaptureTypeWindow() {
        XCTAssertEqual(CaptureType.window.rawValue, "Window")
    }

    func testCaptureTypeScrolling() {
        XCTAssertEqual(CaptureType.scrolling.rawValue, "Scrolling")
    }

    func testCaptureTypeFromRawValue() {
        XCTAssertEqual(CaptureType(rawValue: "Area"), .area)
        XCTAssertEqual(CaptureType(rawValue: "Fullscreen"), .fullscreen)
        XCTAssertEqual(CaptureType(rawValue: "Window"), .window)
        XCTAssertEqual(CaptureType(rawValue: "Scrolling"), .scrolling)
        XCTAssertNil(CaptureType(rawValue: "Unknown"))
    }
}
