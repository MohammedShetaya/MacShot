import XCTest
@testable import MacShot

final class ScreenshotHistoryTests: XCTestCase {

    private func makeHistory() -> ScreenshotHistory {
        ScreenshotHistory(skipLoad: true)
    }

    private func makeTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: image.size))
        image.unlockFocus()
        return image
    }

    // MARK: - Adding Items

    func testAddItemIncreasesCount() {
        let history = makeHistory()
        let image = makeTestImage()

        let expectation = XCTestExpectation(description: "Item added")
        history.add(image: image, filePath: nil, captureType: .area)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(history.items.count, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testAddedItemHasCorrectCaptureType() {
        let history = makeHistory()
        let image = makeTestImage()

        let expectation = XCTestExpectation(description: "Item added")
        history.add(image: image, filePath: nil, captureType: .fullscreen)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(history.items.first?.captureType, "Fullscreen")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testAddedItemHasFilePath() {
        let history = makeHistory()
        let image = makeTestImage()
        let url = URL(fileURLWithPath: "/tmp/test.png")

        let expectation = XCTestExpectation(description: "Item added")
        history.add(image: image, filePath: url, captureType: .area)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(history.items.first?.filePath, "/tmp/test.png")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testNewestItemIsFirst() {
        let history = makeHistory()
        let image = makeTestImage()

        let expectation = XCTestExpectation(description: "Items added")
        history.add(image: image, filePath: nil, captureType: .area)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            history.add(image: image, filePath: nil, captureType: .fullscreen)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(history.items.first?.captureType, "Fullscreen")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - History Limit

    func testHistoryLimitedTo20() {
        let history = makeHistory()
        let image = makeTestImage()

        let expectation = XCTestExpectation(description: "All items added")

        func addItem(remaining: Int) {
            guard remaining > 0 else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    XCTAssertLessThanOrEqual(history.items.count, 20)
                    expectation.fulfill()
                }
                return
            }
            history.add(image: image, filePath: nil, captureType: .area)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                addItem(remaining: remaining - 1)
            }
        }
        addItem(remaining: 25)

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Clearing History

    func testClearRemovesAllItems() {
        let history = makeHistory()
        let image = makeTestImage()

        let expectation = XCTestExpectation(description: "Cleared")
        history.add(image: image, filePath: nil, captureType: .area)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            history.clear()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertTrue(history.items.isEmpty)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Encoding / Decoding

    func testScreenshotHistoryItemEncoding() throws {
        let item = ScreenshotHistoryItem(
            id: UUID(),
            filePath: "/tmp/test.png",
            captureType: "Area",
            timestamp: Date(),
            thumbnailData: nil
        )

        let data = try JSONEncoder().encode(item)
        XCTAssertFalse(data.isEmpty)
    }

    func testScreenshotHistoryItemDecoding() throws {
        let original = ScreenshotHistoryItem(
            id: UUID(),
            filePath: "/tmp/test.png",
            captureType: "Fullscreen",
            timestamp: Date(),
            thumbnailData: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScreenshotHistoryItem.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.filePath, original.filePath)
        XCTAssertEqual(decoded.captureType, original.captureType)
    }

    func testScreenshotHistoryItemRoundTrip() throws {
        let original = ScreenshotHistoryItem(
            id: UUID(),
            filePath: nil,
            captureType: "Window",
            timestamp: Date(),
            thumbnailData: Data([0x01, 0x02, 0x03])
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScreenshotHistoryItem.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertNil(decoded.filePath)
        XCTAssertEqual(decoded.captureType, "Window")
        XCTAssertEqual(decoded.thumbnailData, Data([0x01, 0x02, 0x03]))
    }
}
