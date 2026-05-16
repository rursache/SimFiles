import SwiftUI

struct FileGridView: View {
    @ObservedObject var fileManager: SimFilesFileManager
    let files: [FileItem]
    @Binding var showingDeleteAlert: Bool
    @Binding var showingRenameAlert: Bool

    @State private var dragOver = false

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(files) { file in
                    FileItemView(file: file, isSelected: fileManager.selectedFile?.id == file.id) {
                        if file.isDirectory {
                            fileManager.navigateToPath(file.path)
                        } else {
                            NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                        }
                    } onSelectionChange: { _ in
                        if fileManager.selectedFile?.id == file.id {
                            fileManager.selectedFile = nil
                        } else {
                            fileManager.selectedFile = file
                        }
                    } onCopyFile: {
                        fileManager.selectedFile = file
                        fileManager.copyToPasteboard([file])
                    } onCutFile: {
                        fileManager.selectedFile = file
                        fileManager.cutToPasteboard([file])
                    } onRenameFile: {
                        fileManager.selectedFile = file
                        showingRenameAlert = true
                    } onDeleteFile: {
                        fileManager.selectedFile = file
                        showingDeleteAlert.toggle()
                    }
                    .zIndex(fileManager.selectedFile?.id == file.id ? 1 : 0)
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
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
