import SwiftUI

struct EmptyFolderDropView: View {
    @ObservedObject var fileManager: SimFilesFileManager
    @State private var dragOver = false

    var body: some View {
        ContentUnavailableView {
            Label("Empty Folder", systemImage: "tray")
        } description: {
            Text("Drag files here from Finder to add them.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(dragOver ? AnyShapeStyle(Color.accentColor.opacity(0.08)) : AnyShapeStyle(Color.clear))
        .overlay {
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
