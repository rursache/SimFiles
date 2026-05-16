import Foundation

enum SimulatorError: Error, LocalizedError {
    case invalidResponse
    case filesAppNotFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from xcrun simctl"
        case .filesAppNotFound: "Files app not found on simulator"
        }
    }
}
