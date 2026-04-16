import XCTest
@testable import MacShot

final class DesktopIconManagerTests: XCTestCase {

    // MARK: - State Tracking

    func testSharedInstanceExists() {
        let manager = DesktopIconManager.shared
        XCTAssertNotNil(manager)
    }

    func testInitialStateIsBool() {
        let manager = DesktopIconManager.shared
        // iconsHidden is a Bool — verify it's accessible and has a boolean value
        let state = manager.iconsHidden
        XCTAssertTrue(state == true || state == false)
    }

    func testHideIconsSetsHiddenTrue() {
        let manager = DesktopIconManager.shared
        manager.hideIcons()
        XCTAssertTrue(manager.iconsHidden)
    }

    func testShowIconsSetsHiddenFalse() {
        let manager = DesktopIconManager.shared
        manager.showIcons()
        XCTAssertFalse(manager.iconsHidden)
    }

    func testToggleFromShownToHidden() {
        let manager = DesktopIconManager.shared
        manager.showIcons()
        XCTAssertFalse(manager.iconsHidden)

        manager.toggleIcons()
        XCTAssertTrue(manager.iconsHidden)
    }

    func testToggleFromHiddenToShown() {
        let manager = DesktopIconManager.shared
        manager.hideIcons()
        XCTAssertTrue(manager.iconsHidden)

        manager.toggleIcons()
        XCTAssertFalse(manager.iconsHidden)
    }

    override func tearDown() {
        super.tearDown()
        DesktopIconManager.shared.showIcons()
    }
}
