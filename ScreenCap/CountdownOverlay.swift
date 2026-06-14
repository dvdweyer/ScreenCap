import AppKit

final class CountdownOverlay: NSPanel {
    private let label = NSTextField(labelWithString: "3")
    private var timer: Timer?
    private var count = 3
    private var completion: (() -> Void)?

    init() {
        let size = NSSize(width: 200, height: 200)
        let rect = NSRect(origin: .zero, size: size)
        super.init(contentRect: rect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = true

        let bg = NSView(frame: rect)
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        bg.layer?.cornerRadius = 20
        contentView = bg

        label.font = .boldSystemFont(ofSize: 120)
        label.textColor = .white
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.frame = NSRect(x: 0, y: 20, width: 200, height: 160)
        bg.addSubview(label)
    }

    func show(on screen: NSScreen, completion: @escaping () -> Void) {
        self.completion = completion
        count = 3
        label.stringValue = "3"

        let sw = screen.frame.width
        let sh = screen.frame.height
        let sx = screen.frame.origin.x
        let sy = screen.frame.origin.y
        let origin = NSPoint(x: sx + (sw - 200) / 2,
                             y: sy + (sh - 200) / 2)
        setFrameOrigin(origin)
        orderFrontRegardless()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        count -= 1
        if count > 0 {
            label.stringValue = "\(count)"
        } else {
            timer?.invalidate()
            timer = nil
            orderOut(nil)
            completion?()
            completion = nil
        }
    }
}
