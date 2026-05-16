import SwiftUI
import SwiftUIIntrospect

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
    
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "hammer")
                            .foregroundColor(.accentColor)
                        Text("iOS Simulators")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button {
                            simulatorManager.loadSimulators()
                        } label: {
                          Image(systemName: "arrow.clockwise")
                        }.disabled(systemRequirements.dataLoaded == false || simulatorManager.isLoading == true)
                    }
                    
                    if simulatorManager.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading simulators...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if simulatorManager.simulators.isEmpty {
                        Text("No booted simulators found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(simulatorManager.simulators) { simulator in
                            SimulatorRow(simulator: simulator, isSelected: selectedSimulator?.id == simulator.id) {
                                selectedSimulator = simulator
                            }
                        }
                    }
                }
                
                if let simErrorMessage = simulatorManager.errorMessage {
                    Text(simErrorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 8)
                }
                
                if let fileErrorMessage = fileManager.errorMessage {
                    Text(fileErrorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding()
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(260)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: fileManager.navigateToParent) {
                        Image(systemName: "chevron.left")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.bordered)
                    .disabled(fileManager.currentPath.isEmpty || fileManager.isAtRoot)
                    
                    Divider()
                        .frame(height: 20)
                    
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                        Text(fileManager.currentPath.isEmpty ? "Select a simulator" : URL(fileURLWithPath: fileManager.currentPath).lastPathComponent)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button {
                            showingNewFolderAlert = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(fileManager.currentPath.isEmpty)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 34)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: .rect)
                
                Divider()
                
                if fileManager.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading files...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if fileManager.currentPath.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("Select a Simulator")
                                .font(.title2)
                                .fontWeight(.medium)
                            Text("Choose a booted iOS simulator from the sidebar to browse its Files app storage")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    FileGridView(fileManager: fileManager, showingDeleteAlert: $showingDeleteAlert, showingRenameAlert: $showingRenameAlert)
                }
            }
        }.introspect(.navigationSplitView, on: .macOS(.v13, .v14, .v15)) { splitView in
            if let delegate = splitView.delegate as? NSSplitViewController {
                delegate.splitViewItems.first?.canCollapse = false
                delegate.splitViewItems.first?.canCollapseFromWindowResize = false
            }
        }.alert("New Folder", isPresented: $showingNewFolderAlert) {
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
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        }.alert("Rename", isPresented: $showingRenameAlert) {
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
            Button("Cancel", role: .cancel) {
                renameNewName = ""
            }
        } message: {
            Text("Enter a new name for \"\(fileManager.selectedFile?.name ?? "")\"")
        }.onChange(of: showingRenameAlert) { _, isShowing in
            if isShowing {
                renameNewName = fileManager.selectedFile?.name ?? ""
            }
        }.alert("Delete File", isPresented: $showingDeleteAlert) {
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
        }.alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }.alert("Replace Existing Files", isPresented: $showingOverwriteAlert) {
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
            Button("Cancel", role: .cancel) {
                fileManager.cancelPendingOverwrite()
            }
        } message: {
            if let pending = fileManager.pendingOverwrite {
                let names = pending.conflictingNames.joined(separator: ", ")
                Text("\(pending.conflictingNames.count == 1 ? "\"" + names + "\" already exists" : "The following files already exist: " + names). Do you want to replace \(pending.conflictingNames.count == 1 ? "it" : "them")?")
            }
        }.onChange(of: fileManager.pendingOverwrite != nil) { _, hasPending in
            showingOverwriteAlert = hasPending
        }.alert("System Requirements", isPresented: $showingSystemRequirementsAlert) {
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
        }.onChange(of: systemRequirements.dataLoaded, initial: true) { _, dataLoaded in
            guard dataLoaded else {
                return
            }
            
            if systemRequirements.xcodeInstalled == false || systemRequirements.commandLineToolsInstalled == false {
                showingSystemRequirementsAlert = true
            } else {
                simulatorManager.loadSimulators()
            }
        }.onChange(of: simulatorManager.simulators.count, initial: true) { oldValue, newValue in
            if oldValue == 0 && newValue >= 1 {
                selectedSimulator = simulatorManager.simulators.first!
            }
        }.onChange(of: selectedSimulator) { _, newValue in
            if let path = newValue?.localStoragePath {
                fileManager.resetRoot()
                fileManager.loadFiles(at: path)
            }
        }
    }
}
