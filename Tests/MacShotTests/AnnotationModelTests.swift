import XCTest
@testable import MacShot

final class AnnotationModelTests: XCTestCase {

    // MARK: - AnnotationTool Enum

    func testAnnotationToolCaseCount() {
        XCTAssertEqual(AnnotationTool.allCases.count, 12)
    }

    func testAnnotationToolHasCropCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "crop"))
    }

    func testAnnotationToolHasRectangleCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "rectangle"))
    }

    func testAnnotationToolHasRoundedRectangleCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "roundedRectangle"))
    }

    func testAnnotationToolHasFilledRectangleCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "filledRectangle"))
    }

    func testAnnotationToolHasCircleCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "circle"))
    }

    func testAnnotationToolHasLineCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "line"))
    }

    func testAnnotationToolHasArrowCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "arrow"))
    }

    func testAnnotationToolHasTextCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "text"))
    }

    func testAnnotationToolHasBlurCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "blur"))
    }

    func testAnnotationToolHasCounterCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "counter"))
    }

    func testAnnotationToolHasHighlightCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "highlight"))
    }

    func testAnnotationToolHasPencilCase() {
        XCTAssertNotNil(AnnotationTool(rawValue: "pencil"))
    }

    func testAnnotationToolIdentifiable() {
        let tool = AnnotationTool.arrow
        XCTAssertEqual(tool.id, "arrow")
    }

    func testAnnotationToolInvalidRawValue() {
        XCTAssertNil(AnnotationTool(rawValue: "eraser"))
    }

    // MARK: - AnnotationItem Creation

    func testAnnotationItemDefaultValues() {
        let item = AnnotationItem(tool: .rectangle)

        XCTAssertEqual(item.tool, .rectangle)
        XCTAssertEqual(item.startPoint, .zero)
        XCTAssertEqual(item.endPoint, .zero)
        XCTAssertEqual(item.color, .systemRed)
        XCTAssertEqual(item.lineWidth, 3.0)
        XCTAssertNil(item.text)
        XCTAssertNil(item.counterNumber)
        XCTAssertTrue(item.points.isEmpty)
        XCTAssertEqual(item.fontSize, 18.0)
        XCTAssertFalse(item.isFilled)
        XCTAssertEqual(item.cornerRadius, 12.0)
    }

    func testAnnotationItemCustomValues() {
        let item = AnnotationItem(
            tool: .text,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 100, y: 200),
            color: .blue,
            lineWidth: 5.0,
            text: "Hello",
            fontSize: 24.0,
            isFilled: true,
            cornerRadius: 0
        )

        XCTAssertEqual(item.tool, .text)
        XCTAssertEqual(item.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(item.endPoint, CGPoint(x: 100, y: 200))
        XCTAssertEqual(item.color, .blue)
        XCTAssertEqual(item.lineWidth, 5.0)
        XCTAssertEqual(item.text, "Hello")
        XCTAssertEqual(item.fontSize, 24.0)
        XCTAssertTrue(item.isFilled)
        XCTAssertEqual(item.cornerRadius, 0)
    }

    func testAnnotationItemHasUniqueID() {
        let item1 = AnnotationItem(tool: .line)
        let item2 = AnnotationItem(tool: .line)
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func testAnnotationItemWithCounter() {
        let item = AnnotationItem(tool: .counter, counterNumber: 5)
        XCTAssertEqual(item.tool, .counter)
        XCTAssertEqual(item.counterNumber, 5)
    }

    func testAnnotationItemWithPoints() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 5)]
        let item = AnnotationItem(tool: .pencil, points: points)
        XCTAssertEqual(item.points.count, 3)
        XCTAssertEqual(item.points, points)
    }

    // MARK: - Property Modifications

    func testAnnotationItemToolModification() {
        var item = AnnotationItem(tool: .rectangle)
        item.tool = .circle
        XCTAssertEqual(item.tool, .circle)
    }

    func testAnnotationItemColorModification() {
        var item = AnnotationItem(tool: .line)
        item.color = .green
        XCTAssertEqual(item.color, .green)
    }

    func testAnnotationItemLineWidthModification() {
        var item = AnnotationItem(tool: .arrow)
        item.lineWidth = 10.0
        XCTAssertEqual(item.lineWidth, 10.0)
    }

    func testAnnotationItemTextModification() {
        var item = AnnotationItem(tool: .text)
        XCTAssertNil(item.text)
        item.text = "Updated"
        XCTAssertEqual(item.text, "Updated")
    }

    func testAnnotationItemEndpointModification() {
        var item = AnnotationItem(tool: .line)
        item.startPoint = CGPoint(x: 5, y: 5)
        item.endPoint = CGPoint(x: 50, y: 50)
        XCTAssertEqual(item.startPoint, CGPoint(x: 5, y: 5))
        XCTAssertEqual(item.endPoint, CGPoint(x: 50, y: 50))
    }

    func testAnnotationItemIsFilledModification() {
        var item = AnnotationItem(tool: .filledRectangle)
        XCTAssertFalse(item.isFilled)
        item.isFilled = true
        XCTAssertTrue(item.isFilled)
    }

    func testAnnotationItemFontSizeModification() {
        var item = AnnotationItem(tool: .text)
        item.fontSize = 32.0
        XCTAssertEqual(item.fontSize, 32.0)
    }
}
