import Foundation
import AppKit
import FileMonitor

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

class SimFilesFileManager: ObservableObject {
    @Published var currentFiles: [FileItem] = []
    @Published var currentPath: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFile: FileItem?
    
    private let fileManager = FileManager.default
    private var fileMonitor: FileMonitor?
    private var rootPath: String = ""
    
    var isAtRoot: Bool {
        return currentPath == rootPath
    }
    
    @MainActor
    func loadFiles(at path: String) {
        isLoading = true
        errorMessage = nil
        currentPath = path
        
        // Set root path on first load
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
                    self.selectedFile = nil
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
            
            let isDirectory = resourceValues.isDirectory ?? false
            let size = resourceValues.fileSize.map { Int64($0) }
            let dateModified = resourceValues.contentModificationDate
            
            files.append(FileItem(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                isDirectory: isDirectory,
                size: size,
                dateModified: dateModified
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
    func deleteFiles(_ files: [FileItem]) async throws {
        for file in files {
            try fileManager.removeItem(atPath: file.path)
        }
        selectedFile = nil
        loadFiles(at: currentPath)
    }
    
    func moveFiles(_ files: [FileItem], to destinationPath: String) async throws {
        for file in files {
            let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(file.name)
            try fileManager.moveItem(atPath: file.path, toPath: destinationURL.path)
        }
        await loadFiles(at: currentPath)
    }
    
    func copyFiles(_ files: [FileItem], to destinationPath: String) async throws {
        for file in files {
            let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(file.name)
            try fileManager.copyItem(atPath: file.path, toPath: destinationURL.path)
        }
        await loadFiles(at: currentPath)
    }
    
    func copyFilesFromFinder(_ urls: [URL]) async throws {
        for url in urls {
            let fileName = url.lastPathComponent
            let destinationURL = URL(fileURLWithPath: currentPath).appendingPathComponent(fileName)
            
            if url.hasDirectoryPath {
                try fileManager.copyItem(at: url, to: destinationURL)
            } else {
                try fileManager.copyItem(at: url, to: destinationURL)
            }
        }
        await loadFiles(at: currentPath)
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
        selectedFile = nil
    }
}

extension SimFilesFileManager: FileDidChangeDelegate {
    func fileDidChanged(event: FileChange) {
        self.reloadFilesInCurrentDir()
    }
}

enum FileError: Error, LocalizedError {
    case pathNotFound
    case permissionDenied
    case operationFailed
    
    var errorDescription: String? {
        switch self {
        case .pathNotFound:
            return "Path not found"
        case .permissionDenied:
            return "Permission denied"
        case .operationFailed:
            return "File operation failed"
        }
    }
}
