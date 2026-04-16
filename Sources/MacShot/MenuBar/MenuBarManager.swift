import AppKit
import Combine
import UniformTypeIdentifiers

final class MenuBarManager: NSObject {
    private let appState: AppState
    private var statusItem: NSStatusItem?
    private var shortcutManager: KeyboardShortcutManager?
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func setup() {
        configureCaptureManager()
        createStatusItem()
        registerShortcuts()
        observeStateChanges()
    }

    // MARK: - Status Item

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "MacShot")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        statusItem?.menu = buildMenu()
    }

    private func configureCaptureManager() {
        let manager = CaptureManager.shared
        manager.appState = appState

        manager.onCaptureCompleted = { [weak self] image, captureType in
            guard let self else { return }

            if self.appState.showOverlayAfterCapture {
                OverlayManager.shared.showOverlay(image: image, captureType: captureType)
            }
        }
    }

    private func registerShortcuts() {
        shortcutManager = KeyboardShortcutManager(captureManager: CaptureManager.shared)
        shortcutManager?.register()
    }

    private func observeStateChanges() {
        appState.$recentScreenshots
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        appState.$desktopIconsHidden
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        statusItem?.menu = buildMenu()
    }

    // MARK: - Menu Construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Capture actions
        menu.addItem(captureMenuItem(title: "Capture Area", shortcut: "4", modifiers: [.command, .shift], action: #selector(captureArea)))
        menu.addItem(captureMenuItem(title: "Capture Fullscreen", shortcut: "3", modifiers: [.command, .shift], action: #selector(captureFullscreen)))
        menu.addItem(captureMenuItem(title: "Capture Window", shortcut: "5", modifiers: [.command, .shift], action: #selector(captureWindow)))
        menu.addItem(captureMenuItem(title: "Scrolling Capture", shortcut: "", modifiers: [], action: #selector(captureScrolling)))

        menu.addItem(.separator())

        // Self-Timer submenu
        menu.addItem(selfTimerMenuItem())

        menu.addItem(.separator())

        // Desktop icons toggle
        let hideIconsItem = NSMenuItem(title: "Hide Desktop Icons", action: #selector(toggleDesktopIcons), keyEquivalent: "")
        hideIconsItem.target = self
        hideIconsItem.state = appState.desktopIconsHidden ? .on : .off
        menu.addItem(hideIconsItem)

        menu.addItem(.separator())

        // Open & Pin
        menu.addItem(captureMenuItem(title: "Open...", shortcut: "", modifiers: [], action: #selector(openFile)))
        menu.addItem(captureMenuItem(title: "Pin to Screen...", shortcut: "", modifiers: [], action: #selector(pinLastScreenshot)))

        menu.addItem(.separator())

        // Recent screenshots
        addRecentScreenshotsSection(to: menu)

        menu.addItem(.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = .command
        prefsItem.target = self
        menu.addItem(prefsItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit MacShot", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func captureMenuItem(title: String, shortcut: String, modifiers: NSEvent.ModifierFlags, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: shortcut)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    private func selfTimerMenuItem() -> NSMenuItem {
        let timerItem = NSMenuItem(title: "Self-Timer", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for seconds in [3, 5, 10] {
            let item = NSMenuItem(title: "\(seconds)s", action: #selector(startSelfTimer(_:)), keyEquivalent: "")
            item.target = self
            item.tag = seconds
            if appState.selfTimerSeconds == seconds {
                item.state = .on
            }
            submenu.addItem(item)
        }

        timerItem.submenu = submenu
        return timerItem
    }

    private func addRecentScreenshotsSection(to menu: NSMenu) {
        let recentItems = Array(appState.recentScreenshots.prefix(5))

        if recentItems.isEmpty {
            let emptyItem = NSMenuItem(title: "No Recent Screenshots", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        let headerItem = NSMenuItem(title: "Recent Screenshots", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        for (index, screenshot) in recentItems.enumerated() {
            let filename = screenshot.filePath?.lastPathComponent ?? "\(screenshot.captureType.rawValue) Capture"
            let timeString = formatter.string(from: screenshot.timestamp)
            let title = "\(filename)  —  \(timeString)"

            let item = NSMenuItem(title: title, action: #selector(openRecentScreenshot(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index

            // Thumbnail
            let thumbnail = createThumbnail(from: screenshot.image, maxSize: 16)
            item.image = thumbnail

            menu.addItem(item)
        }
    }

    private func createThumbnail(from image: NSImage, maxSize: CGFloat) -> NSImage {
        let aspect = image.size.width / image.size.height
        let thumbSize: NSSize
        if aspect > 1 {
            thumbSize = NSSize(width: maxSize, height: maxSize / aspect)
        } else {
            thumbSize = NSSize(width: maxSize * aspect, height: maxSize)
        }

        let thumbnail = NSImage(size: thumbSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbSize), from: .zero, operation: .sourceOver, fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail
    }

    // MARK: - Actions

    @objc private func captureArea() {
        CaptureManager.shared.captureArea()
    }

    @objc private func captureFullscreen() {
        CaptureManager.shared.captureFullscreen()
    }

    @objc private func captureWindow() {
        CaptureManager.shared.captureWindow()
    }

    @objc private func captureScrolling() {
        CaptureManager.shared.captureScrolling()
    }

    @objc private func startSelfTimer(_ sender: NSMenuItem) {
        let seconds = sender.tag
        appState.selfTimerSeconds = seconds
        CaptureManager.shared.captureWithTimer(seconds: seconds, mode: .fullscreen)
        rebuildMenu()
    }

    @objc private func toggleDesktopIcons() {
        DesktopIconManager.shared.toggleIcons()
        appState.desktopIconsHidden = DesktopIconManager.shared.iconsHidden
    }

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let image = NSImage(contentsOf: url) else { return }
            OverlayManager.shared.showOverlay(image: image, captureType: .area)
            _ = self
        }
    }

    @objc private func pinLastScreenshot() {
        guard let lastScreenshot = appState.recentScreenshots.first else { return }
        OverlayManager.shared.showOverlay(image: lastScreenshot.image, captureType: lastScreenshot.captureType)
    }

    @objc private func openRecentScreenshot(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index < appState.recentScreenshots.count else { return }
        let screenshot = appState.recentScreenshots[index]
        OverlayManager.shared.showOverlay(image: screenshot.image, captureType: screenshot.captureType)
    }

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

}
