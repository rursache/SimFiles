import Foundation

enum FileSortOrder: String, CaseIterable, Identifiable {
    case name = "Name"
    case size = "Size"
    case dateModified = "Date Modified"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .name: "textformat"
        case .size: "externaldrive"
        case .dateModified: "calendar"
        }
    }
}
