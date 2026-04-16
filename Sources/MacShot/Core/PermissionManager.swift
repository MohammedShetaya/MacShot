import AppKit
import ScreenCaptureKit

final class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestScreenCapturePermission() {
        if !hasScreenCapturePermission {
            CGRequestScreenCaptureAccess()
        }
    }
}
