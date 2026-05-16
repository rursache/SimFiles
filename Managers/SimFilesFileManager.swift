import Foundation
import AppKit
import FileMonitor

class SimFilesFileManager: ObservableObject {
    @Published var currentFiles: [FileItem] = []
    @Published var currentPath: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFiles: Set<String> = []
    @Published var selectionAnchor: String?
    @Published var pendingOverwrite: PendingOverwrite?

    var selectedFileItems: [FileItem] {
        currentFiles.filter { selectedFiles.contains($0.path) }
    }

    var primarySelectedFile: FileItem? {
        guard selectedFiles.count == 1, let path = selectedFiles.first else { return nil }
        return currentFiles.first { $0.path == path }
    }

    func selectOnly(_ file: FileItem) {
        selectedFiles = [file.path]
        selectionAnchor = file.path
    }

    func toggleSelection(_ file: FileItem) {
        if selectedFiles.contains(file.path) {
            selectedFiles.remove(file.path)
            if selectionAnchor == file.path { selectionAnchor = selectedFiles.first }
        } else {
            selectedFiles.insert(file.path)
            selectionAnchor = file.path
        }
    }

    func extendSelection(to file: FileItem, in displayedFiles: [FileItem]) {
        guard let anchor = selectionAnchor,
              let anchorIdx = displayedFiles.firstIndex(where: { $0.path == anchor }),
              let targetIdx = displayedFiles.firstIndex(where: { $0.path == file.path }) else {
            selectOnly(file)
            return
        }
        let range = anchorIdx <= targetIdx ? anchorIdx...targetIdx : targetIdx...anchorIdx
        selectedFiles = Set(displayedFiles[range].map(\.path))
    }

    func clearSelection() {
        selectedFiles = []
        selectionAnchor = nil
    }

    private let fileManager = FileManager.default
    private var fileMonitor: FileMonitor?
    private(set) var rootPath: String = ""
    private let clipboardOperationPasteboardType = NSPasteboard.PasteboardType("ro.randusoft.simfiles.clipboard-operation")

    private enum ClipboardOperation: String {
        case copy
        case cut
    }

    var isAtRoot: Bool {
        return currentPath == rootPath
    }

    @MainActor
    func loadFiles(at path: String) {
        isLoading = true
        errorMessage = nil
        currentPath = path

        if rootPath.isEmpty {
            rootPath = path
        }

        self.reloadFilesInCurrentDir()

        self.fileMonitor = try? FileMonitor(directory: URL(filePath: path), delegate: self)
        try? self.fileMonitor?.start()
    }

    private func reloadFilesInCurrentDir() {
        Task {
            do {
                let files = try await getFiles(at: currentPath)
                await MainActor.run {
                    self.currentFiles = files
                    let surviving = Set(files.map(\.path))
                    self.selectedFiles = self.selectedFiles.intersection(surviving)
                    if let anchor = self.selectionAnchor, !surviving.contains(anchor) {
                        self.selectionAnchor = self.selectedFiles.first
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func getFiles(at path: String) async throws -> [FileItem] {
        let url = URL(fileURLWithPath: path)

        guard fileManager.fileExists(atPath: path) else {
            throw FileError.pathNotFound
        }

        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey
        ])

        var files: [FileItem] = []

        for fileURL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let resourceValues = try fileURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey
            ])

            files.append(FileItem(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                isDirectory: resourceValues.isDirectory ?? false,
                size: resourceValues.fileSize.map { Int64($0) },
                dateModified: resourceValues.contentModificationDate
            ))
        }

        return files
    }

    func createFolder(named name: String) async throws {
        let newFolderPath = URL(fileURLWithPath: currentPath).appendingPathComponent(name).path
        try fileManager.createDirectory(atPath: newFolderPath, withIntermediateDirectories: false)
        await loadFiles(at: currentPath)
    }

    @MainActor
    func renameFile(_ file: FileItem, to newName: String) async throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != file.name else { return }

        let destinationURL = URL(fileURLWithPath: file.path).deletingLastPathComponent().appendingPathComponent(trimmedName)
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw FileError.operationFailed
        }

        try fileManager.moveItem(atPath: file.path, toPath: destinationURL.path)
        clearSelection()
        loadFiles(at: currentPath)
    }

    @MainActor
    func deleteFiles(_ files: [FileItem]) async throws {
        for file in files {
            try fileManager.removeItem(atPath: file.path)
        }
        loadFiles(at: currentPath)
    }

    func moveFiles(_ files: [FileItem], to destinationPath: String, overwrite: Bool = false) async throws {
        if !overwrite {
            let conflicts = conflictingNames(for: files.map(\.name), in: destinationPath)
            if !conflicts.isEmpty {
                await MainActor.run {
                    pendingOverwrite = PendingOverwrite(conflictingNames: conflicts, operation: .moveInternal(files: files, destination: destinationPath))
                }
                return
            }
        }
        for file in files {
            let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(file.name)
            if overwrite { try? fileManager.removeItem(at: destinationURL) }
            try fileManager.moveItem(atPath: file.path, toPath: destinationURL.path)
        }
        await loadFiles(at: currentPath)
    }

    func copyFiles(_ files: [FileItem], to destinationPath: String, overwrite: Bool = false) async throws {
        if !overwrite {
            let conflicts = conflictingNames(for: files.map(\.name), in: destinationPath)
            if !conflicts.isEmpty {
                await MainActor.run {
                    pendingOverwrite = PendingOverwrite(conflictingNames: conflicts, operation: .copyInternal(files: files, destination: destinationPath))
                }
                return
            }
        }
        for file in files {
            let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(file.name)
            if overwrite { try? fileManager.removeItem(at: destinationURL) }
            try fileManager.copyItem(atPath: file.path, toPath: destinationURL.path)
        }
        await loadFiles(at: currentPath)
    }

    func copyFilesFromFinder(_ urls: [URL], overwrite: Bool = false) async throws {
        if !overwrite {
            let conflicts = conflictingNames(for: urls.map(\.lastPathComponent), in: currentPath)
            if !conflicts.isEmpty {
                await MainActor.run {
                    pendingOverwrite = PendingOverwrite(conflictingNames: conflicts, operation: .copyFromFinder(urls: urls))
                }
                return
            }
        }
        for url in urls {
            let destinationURL = URL(fileURLWithPath: currentPath).appendingPathComponent(url.lastPathComponent)
            if overwrite { try? fileManager.removeItem(at: destinationURL) }
            try fileManager.copyItem(at: url, to: destinationURL)
        }
        await loadFiles(at: currentPath)
    }

    @MainActor
    func executePendingOverwrite() async throws {
        guard let pending = pendingOverwrite else { return }
        pendingOverwrite = nil
        switch pending.operation {
        case .copyFromFinder(let urls):
            try await copyFilesFromFinder(urls, overwrite: true)
        case .copyInternal(let files, let destination):
            try await copyFiles(files, to: destination, overwrite: true)
        case .moveInternal(let files, let destination):
            try await moveFiles(files, to: destination, overwrite: true)
        }
    }

    @MainActor
    func cancelPendingOverwrite() {
        pendingOverwrite = nil
    }

    private func conflictingNames(for names: [String], in directoryPath: String) -> [String] {
        names.filter { fileManager.fileExists(atPath: URL(fileURLWithPath: directoryPath).appendingPathComponent($0).path) }
    }

    func copyToPasteboard(_ files: [FileItem]) {
        writeFilesToPasteboard(files, operation: .copy)
    }

    func cutToPasteboard(_ files: [FileItem]) {
        writeFilesToPasteboard(files, operation: .cut)
    }

    private func writeFilesToPasteboard(_ files: [FileItem], operation: ClipboardOperation) {
        let urls = files.map { URL(fileURLWithPath: $0.path) as NSURL }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls)
        pasteboard.setString(operation.rawValue, forType: clipboardOperationPasteboardType)
    }

    @MainActor func navigateToParent() {
        let parentPath = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path

        if parentPath != currentPath && parentPath.count >= rootPath.count && parentPath.hasPrefix(rootPath) {
            loadFiles(at: parentPath)
        }
    }

    @MainActor func navigateToPath(_ path: String) {
        loadFiles(at: path)
    }

    func resetRoot() {
        rootPath = ""
        currentPath = ""
        currentFiles = []
        clearSelection()
    }
}

extension SimFilesFileManager: FileDidChangeDelegate {
    func fileDidChanged(event: FileChange) {
        self.reloadFilesInCurrentDir()
    }
}
