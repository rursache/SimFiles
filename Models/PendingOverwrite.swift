import Foundation

struct PendingOverwrite {
    let conflictingNames: [String]
    let operation: Operation

    enum Operation {
        case copyFromFinder(urls: [URL])
        case copyInternal(files: [FileItem], destination: String)
        case moveInternal(files: [FileItem], destination: String)
    }
}
