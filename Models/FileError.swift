import Foundation

enum FileError: Error, LocalizedError {
    case pathNotFound
    case permissionDenied
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .pathNotFound: "Path not found"
        case .permissionDenied: "Permission denied"
        case .operationFailed: "File operation failed"
        }
    }
}
