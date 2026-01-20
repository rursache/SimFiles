//
//  FileGridView.swift
//  SimFiles
//
//  Created by Radu Ursache on 24.08.2025.
//

import SwiftUI

struct FileGridView: View {
    @ObservedObject var fileManager: SimFilesFileManager
    @Binding var showingDeleteAlert: Bool
    
    @State private var dragOver = false
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(120)), count: 6), spacing: 20) {
                ForEach(fileManager.currentFiles) { file in
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
                    } onDeleteFile: {
                        fileManager.selectedFile = file
                        showingDeleteAlert.toggle()
                    }.zIndex(fileManager.selectedFile?.id == file.id ? 1 : 0)
                }
            }
            .padding(.vertical)
            .padding(.horizontal, 16)
        }.onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            Task {
                var urls: [URL] = []
                
                for provider in providers {
                    await withCheckedContinuation { continuation in
                        _ = provider.loadObject(ofClass: URL.self) { url, error in
                            if let url = url {
                                urls.append(url)
                            }
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
        }.background(dragOver ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}
