import Foundation
import AppKit
import CoreTransferable
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable, Sendable, Transferable {
    var id: String { path }
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

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { item in
            URL(fileURLWithPath: item.path)
        }
    }
}
