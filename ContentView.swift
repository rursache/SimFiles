import SwiftUI

struct ContentView: View {
    @StateObject private var systemRequirements = SystemRequirements()
    @StateObject private var simulatorManager = SimulatorManager()
    @StateObject private var fileManager = SimFilesFileManager()

    @State private var selectedSimulator: Simulator?
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showingDeleteAlert = false
    @State private var showingRenameAlert = false
    @State private var renameNewName = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSystemRequirementsAlert = false
    @State private var showingOverwriteAlert = false
    @State private var searchText = ""
    @State private var sortOrder: FileSortOrder = .name

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 320)
        } detail: {
            detail
        }
        .alert("New Folder", isPresented: $showingNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                Task {
                    do {
                        try await fileManager.createFolder(named: newFolderName)
                        newFolderName = ""
                    } catch {
                        errorMessage = "Failed to create folder: \(error.localizedDescription)"
                        showingErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
        .alert("Rename", isPresented: $showingRenameAlert) {
            TextField("New name", text: $renameNewName)
            Button("Rename") {
                Task {
                    do {
                        if let selectedFile = fileManager.selectedFile {
                            try await fileManager.renameFile(selectedFile, to: renameNewName)
                        }
                        renameNewName = ""
                    } catch {
                        errorMessage = "Failed to rename: \(error.localizedDescription)"
                        showingErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { renameNewName = "" }
        } message: {
            Text("Enter a new name for \"\(fileManager.selectedFile?.name ?? "")\"")
        }
        .onChange(of: showingRenameAlert) { _, isShowing in
            if isShowing { renameNewName = fileManager.selectedFile?.name ?? "" }
        }
        .alert("Delete File", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        if let selectedFile = fileManager.selectedFile {
                            try await fileManager.deleteFiles([selectedFile])
                        }
                    } catch {
                        errorMessage = "Failed to delete file: \(error.localizedDescription)"
                        showingErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(fileManager.selectedFile?.name ?? "")\"?")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Replace Existing Files", isPresented: $showingOverwriteAlert) {
            Button("Replace", role: .destructive) {
                Task {
                    do {
                        try await fileManager.executePendingOverwrite()
                    } catch {
                        errorMessage = "Failed to copy files: \(error.localizedDescription)"
                        showingErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { fileManager.cancelPendingOverwrite() }
        } message: {
            if let pending = fileManager.pendingOverwrite {
                let names = pending.conflictingNames.joined(separator: ", ")
                Text("\(pending.conflictingNames.count == 1 ? "\"" + names + "\" already exists" : "The following files already exist: " + names). Do you want to replace \(pending.conflictingNames.count == 1 ? "it" : "them")?")
            }
        }
        .onChange(of: fileManager.pendingOverwrite != nil) { _, hasPending in
            showingOverwriteAlert = hasPending
        }
        .alert("System Requirements", isPresented: $showingSystemRequirementsAlert) {
            Button("Check App Store") {
                if let url = URL(string: "macappstore://itunes.apple.com/app/xcode/id497799835") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Install Command Line Tools") {
                if let url = URL(string: "https://developer.apple.com/xcode/") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("OK") { }
        } message: {
            Text(systemRequirements.errorMessage ?? "System requirements not met")
        }
        .onChange(of: systemRequirements.dataLoaded, initial: true) { _, dataLoaded in
            guard dataLoaded else { return }
            if systemRequirements.xcodeInstalled == false || systemRequirements.commandLineToolsInstalled == false {
                showingSystemRequirementsAlert = true
            } else {
                simulatorManager.loadSimulators()
            }
        }
        .onChange(of: simulatorManager.simulators.count, initial: true) { oldValue, newValue in
            if oldValue == 0 && newValue >= 1 {
                selectedSimulator = simulatorManager.simulators.first!
            }
        }
        .onChange(of: selectedSimulator) { _, newValue in
            if let path = newValue?.localStoragePath {
                fileManager.resetRoot()
                fileManager.loadFiles(at: path)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("iOS Simulators", systemImage: "hammer.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    simulatorManager.loadSimulators()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(systemRequirements.dataLoaded == false || simulatorManager.isLoading)
            }

            if simulatorManager.isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading simulators...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if simulatorManager.simulators.isEmpty {
                Text("No booted simulators found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(simulatorManager.simulators) { simulator in
                        SimulatorRow(simulator: simulator, isSelected: selectedSimulator?.id == simulator.id) {
                            selectedSimulator = simulator
                        }
                    }
                }
            }

            if let simErrorMessage = simulatorManager.errorMessage {
                Text(simErrorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.top, 4)
            }

            if let fileErrorMessage = fileManager.errorMessage {
                Text(fileErrorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
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
                ContentUnavailableView {
                    Label("Empty Folder", systemImage: "tray")
                } description: {
                    Text("Drag files here from Finder to add them.")
                }
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
