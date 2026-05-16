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
            SidebarView(
                systemRequirements: systemRequirements,
                simulatorManager: simulatorManager,
                fileManager: fileManager,
                selectedSimulator: $selectedSimulator
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 320)
        } detail: {
            FileBrowserView(
                fileManager: fileManager,
                searchText: $searchText,
                sortOrder: $sortOrder,
                showingDeleteAlert: $showingDeleteAlert,
                showingRenameAlert: $showingRenameAlert,
                showingNewFolderAlert: $showingNewFolderAlert
            )
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
                        if let target = fileManager.primarySelectedFile {
                            try await fileManager.renameFile(target, to: renameNewName)
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
            Text("Enter a new name for \"\(fileManager.primarySelectedFile?.name ?? "")\"")
        }
        .onChange(of: showingRenameAlert) { _, isShowing in
            if isShowing { renameNewName = fileManager.primarySelectedFile?.name ?? "" }
        }
        .alert(fileManager.selectedFileItems.count > 1 ? "Delete Items" : "Delete File", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await fileManager.deleteFiles(fileManager.selectedFileItems)
                    } catch {
                        errorMessage = "Failed to delete: \(error.localizedDescription)"
                        showingErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let items = fileManager.selectedFileItems
            if items.count == 1 {
                Text("Are you sure you want to delete \"\(items[0].name)\"?")
            } else {
                Text("Are you sure you want to delete \(items.count) items?")
            }
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
}
