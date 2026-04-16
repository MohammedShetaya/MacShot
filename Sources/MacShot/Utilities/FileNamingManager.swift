import Foundation
import AppKit

enum FileNamingManager {
    static func generateFilename(format: ImageFormat, pattern: String? = nil) -> String {
        let template = pattern ?? "MacShot {date} at {time}"
        let now = Date()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: now)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH.mm.ss"
        let timeString = timeFormatter.string(from: now)

        let basename = template
            .replacingOccurrences(of: "{date}", with: dateString)
            .replacingOccurrences(of: "{time}", with: timeString)

        let sanitized = sanitizeFilename(basename)

        let isRetina = NSScreen.main?.backingScaleFactor ?? 1.0 > 1.0
        let suffix = isRetina ? "@2x" : ""

        return "\(sanitized)\(suffix).\(format.fileExtension)"
    }

    static func defaultFilename(format: ImageFormat) -> String {
        generateFilename(format: format, pattern: nil)
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?\"<>|*")
        let components = name.unicodeScalars.filter { !invalidCharacters.contains($0) }
        return String(String.UnicodeScalarView(components))
    }
}

extension ImageFormat {
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpeg"
        case .tiff: return "tiff"
        }
    }
}
