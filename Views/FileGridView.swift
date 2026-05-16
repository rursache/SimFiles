import SwiftUI

struct FileGridView: View {
    @ObservedObject var fileManager: SimFilesFileManager
    let files: [FileItem]
    @Binding var showingDeleteAlert: Bool
    @Binding var showingRenameAlert: Bool

    @State private var dragOver = false

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 16)]

    private func targetsFor(_ file: FileItem) -> [FileItem] {
        if fileManager.selectedFiles.contains(file.path) {
            return fileManager.selectedFileItems
        }
        return [file]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(files) { file in
                    FileItemView(file: file, isSelected: fileManager.selectedFiles.contains(file.path)) {
                        if file.isDirectory {
                            fileManager.navigateToPath(file.path)
                        } else {
                            NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                        }
                    } onClick: { modifiers in
                        if modifiers.contains(.shift) {
                            fileManager.extendSelection(to: file, in: files)
                        } else if modifiers.contains(.command) {
                            fileManager.toggleSelection(file)
                        } else {
                            if fileManager.selectedFiles == [file.path] {
                                fileManager.clearSelection()
                            } else {
                                fileManager.selectOnly(file)
                            }
                        }
                    } onCopyFile: {
                        fileManager.copyToPasteboard(targetsFor(file))
                    } onCutFile: {
                        fileManager.cutToPasteboard(targetsFor(file))
                    } onRenameFile: {
                        fileManager.selectOnly(file)
                        showingRenameAlert = true
                    } onDeleteFile: {
                        if !fileManager.selectedFiles.contains(file.path) {
                            fileManager.selectOnly(file)
                        }
                        showingDeleteAlert.toggle()
                    }
                    .zIndex(fileManager.selectedFiles.contains(file.path) ? 1 : 0)
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .dragContainer(for: FileItem.self) { ids in
            files.filter { ids.contains($0.id) }
        }
        .dragContainerSelection(Array(fileManager.selectedFiles))
        .background(dragOver ? AnyShapeStyle(Color.accentColor.opacity(0.08)) : AnyShapeStyle(Color.clear))
        .overlay(alignment: .top) {
            if dragOver {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            Task {
                var urls: [URL] = []
                for provider in providers {
                    await withCheckedContinuation { continuation in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url { urls.append(url) }
                            continuation.resume()
                        }
                    }
                }
                if !urls.isEmpty {
                    do {
                        try await fileManager.copyFilesFromFinder(urls)
                    } catch {
                        await MainActor.run {
                            fileManager.errorMessage = "Failed to copy files: \(error.localizedDescription)"
                        }
                    }
                }
            }
            return true
        }
    }
}
