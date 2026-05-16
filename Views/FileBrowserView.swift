import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var fileManager: SimFilesFileManager
    @Binding var searchText: String
    @Binding var sortOrder: FileSortOrder
    @Binding var showingDeleteAlert: Bool
    @Binding var showingRenameAlert: Bool
    @Binding var showingNewFolderAlert: Bool

    var body: some View {
        Group {
            if fileManager.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading files...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if fileManager.currentPath.isEmpty {
                ContentUnavailableView {
                    Label("Select a Simulator", systemImage: "iphone.and.arrow.forward")
                } description: {
                    Text("Choose a booted iOS simulator from the sidebar to browse its Files app storage.")
                }
            } else if fileManager.currentFiles.isEmpty {
                EmptyFolderDropView(fileManager: fileManager)
            } else if filteredAndSortedFiles.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                FileGridView(
                    fileManager: fileManager,
                    files: filteredAndSortedFiles,
                    showingDeleteAlert: $showingDeleteAlert,
                    showingRenameAlert: $showingRenameAlert
                )
            }
        }
        .navigationTitle("")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search this folder")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    fileManager.navigateToParent()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(fileManager.currentPath.isEmpty || fileManager.isAtRoot)
                .help("Back")
            }

            ToolbarItem(placement: .navigation) {
                if !fileManager.currentPath.isEmpty {
                    BreadcrumbView(
                        rootPath: fileManager.rootPath,
                        currentPath: fileManager.currentPath
                    ) { path in
                        fileManager.navigateToPath(path)
                    }
                }
            }.sharedBackgroundVisibility(.hidden)

            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Sort by", selection: $sortOrder) {
                        ForEach(FileSortOrder.allCases) { order in
                            Label(order.rawValue, systemImage: order.systemImage).tag(order)
                        }
                    }.pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .help("Sort")
                .disabled(fileManager.currentPath.isEmpty)

                Button {
                    showingNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .disabled(fileManager.currentPath.isEmpty)
                .help("New Folder")
            }
        }
    }

    private var filteredAndSortedFiles: [FileItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty
            ? fileManager.currentFiles
            : fileManager.currentFiles.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }

        switch sortOrder {
        case .name:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            return filtered.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
        case .dateModified:
            return filtered.sorted { ($0.dateModified ?? .distantPast) > ($1.dateModified ?? .distantPast) }
        }
    }
}
