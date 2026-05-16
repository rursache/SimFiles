import Foundation
import AppKit

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
    let dateModified: Date?

    var icon: NSImage {
        if isDirectory {
            NSWorkspace.shared.icon(for: .folder)
        } else {
            NSWorkspace.shared.icon(forFile: path)
        }
    }

    var formattedSize: String {
        guard let size = size, !isDirectory else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
