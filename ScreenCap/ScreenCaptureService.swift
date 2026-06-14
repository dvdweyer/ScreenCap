import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

enum CaptureError: LocalizedError {
    case noDisplay
    case cgImageConversionFailed
    case writeFailed(URL)

    var errorDescription: String? {
        switch self {
        case .noDisplay:                 return "Could not find the target display for capture."
        case .cgImageConversionFailed:   return "Failed to convert the captured frame to an image."
        case .writeFailed(let u):        return "Failed to write PNG to \(u.path)."
        }
    }
}

enum ScreenCaptureService {
    static func capture(displayID: CGDirectDisplayID, to directory: URL) async throws -> URL {
        let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                           onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.noDisplay
        }

        if #available(macOS 14.2, *) {
            return try await captureWithScreenshotManager(display: display, to: directory)
        } else {
            return try await captureWithStream(display: display, to: directory)
        }
    }

    // MARK: - macOS 14.2+

    @available(macOS 14.2, *)
    private static func captureWithScreenshotManager(display: SCDisplay, to directory: URL) async throws -> URL {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(CGDisplayPixelsWide(display.displayID))
        config.height = Int(CGDisplayPixelsHigh(display.displayID))
        config.showsCursor = false

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                  configuration: config)
        return try save(image: cgImage, to: directory)
    }

    // MARK: - macOS 13.0

    private static func captureWithStream(display: SCDisplay, to directory: URL) async throws -> URL {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(CGDisplayPixelsWide(display.displayID))
        config.height = Int(CGDisplayPixelsHigh(display.displayID))
        config.showsCursor = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let capturer = SingleFrameCapturer()
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(capturer, type: .screen, sampleHandlerQueue: .global())
        try await stream.startCapture()
        let cgImage = try await capturer.waitForFrame()
        try await stream.stopCapture()

        return try save(image: cgImage, to: directory)
    }

    // MARK: - Shared

    private static func save(image: CGImage, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("ScreenCap \(timestamp()).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                         UTType.png.identifier as CFString,
                                                         1, nil) else {
            throw CaptureError.writeFailed(url)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CaptureError.writeFailed(url) }
        return url
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return f.string(from: Date())
    }
}

// MARK: - Single-frame SCStream output (macOS 13)

private final class SingleFrameCapturer: NSObject, SCStreamOutput {
    private var continuation: CheckedContinuation<CGImage, Error>?

    func waitForFrame() async throws -> CGImage {
        try await withCheckedThrowingContinuation { self.continuation = $0 }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let continuation else { return }
        self.continuation = nil

        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            continuation.resume(throwing: CaptureError.cgImageConversionFailed)
            return
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(ciImage, from: ciImage.extent) else {
            continuation.resume(throwing: CaptureError.cgImageConversionFailed)
            return
        }
        continuation.resume(returning: cgImage)
    }
}
