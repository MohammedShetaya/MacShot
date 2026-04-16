import Foundation

final class DesktopIconManager {
    static let shared = DesktopIconManager()

    private(set) var iconsHidden: Bool = false

    private init() {
        iconsHidden = readCurrentState()
    }

    func hideIcons() {
        runShellCommand("defaults write com.apple.finder CreateDesktop false")
        restartFinder()
        iconsHidden = true
    }

    func showIcons() {
        runShellCommand("defaults write com.apple.finder CreateDesktop true")
        restartFinder()
        iconsHidden = false
    }

    func toggleIcons() {
        if iconsHidden {
            showIcons()
        } else {
            hideIcons()
        }
    }

    private func readCurrentState() -> Bool {
        let output = runShellCommand("defaults read com.apple.finder CreateDesktop")
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "0"
    }

    private func restartFinder() {
        runShellCommand("killall Finder")
    }

    @discardableResult
    private func runShellCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
