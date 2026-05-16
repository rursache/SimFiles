import Foundation

struct Simulator: Identifiable, Equatable {
    let id: String
    let name: String
    let os: String
    let localStoragePath: String?
}
