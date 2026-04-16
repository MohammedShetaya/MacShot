import AppKit
import SwiftUI

final class SelfTimerManager {
    private var timerWindow: NSWindow?
    private var countdownTimer: Timer?
    private var remainingSeconds: Int = 0
    private var isCancelled = false

    func startTimer(seconds: Int, mode: CaptureType, captureManager: CaptureManager, completion: @escaping () -> Void) {
        cancel()
        isCancelled = false
        remainingSeconds = seconds

        showCountdownWindow()
        updateCountdownDisplay()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self, !self.isCancelled else {
                timer.invalidate()
                return
            }

            self.remainingSeconds -= 1

            if self.remainingSeconds <= 0 {
                timer.invalidate()
                self.dismissCountdownWindow()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.performCapture(mode: mode, captureManager: captureManager)
                    completion()
                }
            } else {
                self.updateCountdownDisplay()
            }
        }
    }

    func cancel() {
        isCancelled = true
        countdownTimer?.invalidate()
        countdownTimer = nil
        dismissCountdownWindow()
    }

    // MARK: - Private

    private func performCapture(mode: CaptureType, captureManager: CaptureManager) {
        switch mode {
        case .area:
            captureManager.captureArea()
        case .fullscreen:
            captureManager.captureFullscreen()
        case .window:
            captureManager.captureWindow()
        case .scrolling:
            captureManager.captureScrolling()
        }
    }

    private func showCountdownWindow() {
        guard let screen = NSScreen.main else { return }

        let windowSize = CGSize(width: 200, height: 200)
        let origin = CGPoint(
            x: screen.frame.midX - windowSize.width / 2,
            y: screen.frame.midY - windowSize.height / 2
        )

        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let hostingView = NSHostingView(rootView: CountdownView(seconds: remainingSeconds))
        window.contentView = hostingView
        window.orderFront(nil)

        timerWindow = window
    }

    private func updateCountdownDisplay() {
        guard let window = timerWindow else { return }
        let hostingView = NSHostingView(rootView: CountdownView(seconds: remainingSeconds))
        window.contentView = hostingView
    }

    private func dismissCountdownWindow() {
        timerWindow?.orderOut(nil)
        timerWindow = nil
    }
}

// MARK: - Countdown SwiftUI View

private struct CountdownView: View {
    let seconds: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.7))
                .frame(width: 160, height: 160)

            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                .frame(width: 160, height: 160)

            Circle()
                .trim(from: 0, to: CGFloat(seconds) / CGFloat(max(seconds, 1)))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: seconds)

            Text("\(seconds)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 200, height: 200)
    }
}
