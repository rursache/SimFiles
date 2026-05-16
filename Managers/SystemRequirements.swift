import Foundation

class SystemRequirements: ObservableObject {
    @Published var xcodeInstalled = true
    @Published var commandLineToolsInstalled = true
    @Published var dataLoaded = false
    @Published var errorMessage: String?
    
    struct DependencyError: Error, LocalizedError {
        let message: String
        
        var errorDescription: String? {
            return message
        }
    }
    
    init() {
         checkSystemRequirements()
    }
    
    func checkSystemRequirements() {
        Task {
            let xcodeCheck = await checkXcodeInstallation()
            let cltCheck = await checkCommandLineTools()
            
            await MainActor.run {
                self.xcodeInstalled = xcodeCheck
                self.commandLineToolsInstalled = cltCheck
                
                self.dataLoaded = true
                
                print("SystemRequirements:")
                print("- Xcode installed: \(xcodeCheck)")
                print("- Command Line Tools installed: \(cltCheck)")
                
                if !xcodeCheck {
                    self.errorMessage = "Xcode is not installed or not found in /Applications/Xcode.app"
                } else if !cltCheck {
                    self.errorMessage = "Xcode Command Line Tools are not installed"
                } else {
                    self.errorMessage = nil
                }
            }
        }
    }
    
    private func checkXcodeInstallation() async -> Bool {
        let xcodeAppPath = "/Applications/Xcode.app"
        let xcodeExecutable = "\(xcodeAppPath)/Contents/MacOS/Xcode"
        
        let fileManager = FileManager.default
        
        // Check if Xcode.app exists
        guard fileManager.fileExists(atPath: xcodeAppPath) else {
            print("Xcode check failed: /Applications/Xcode.app not found")
            return false
        }
        
        // Check if Xcode executable exists
        guard fileManager.fileExists(atPath: xcodeExecutable) else {
            print("Xcode check failed: Xcode executable not found at \(xcodeExecutable)")
            return false
        }
        
        print("Xcode app and executable found, checking version...")
        
        // Try to get Xcode version - use return await to ensure we wait for completion
        return await withCheckedContinuation { continuation in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
                process.arguments = ["-version"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                process.terminationHandler = { process in
                    let success = process.terminationStatus == 0
                    print("xcodebuild -version exit code: \(process.terminationStatus)")
                    if success {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8) {
                            print("xcodebuild output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                        }
                    }
                    continuation.resume(returning: success)
                }
                
                try process.run()
            } catch {
                print("Failed to run xcodebuild: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    private func checkCommandLineTools() async -> Bool {
        print("Checking Command Line Tools...")
        
        return await withCheckedContinuation { continuation in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
                process.arguments = ["-v"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                process.terminationHandler = { process in
                    print("xcode-select -v exit code: \(process.terminationStatus)")
                    
                    if process.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8) {
                            print("xcrun --find simctl output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                        }
                        
                        // Double check by trying to run simctl help
                        self.checkSimctlHelp { success in
                            continuation.resume(returning: success)
                        }
                    } else {
                        print("xcrun --find simctl failed")
                        continuation.resume(returning: false)
                    }
                }
                
                try process.run()
            } catch {
                print("Failed to run xcrun --find simctl: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    private func checkSimctlHelp(completion: @escaping (Bool) -> Void) {
        do {
            let simctlProcess = Process()
            simctlProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            simctlProcess.arguments = ["simctl", "help"]
            
            let simctlPipe = Pipe()
            simctlProcess.standardOutput = simctlPipe
            simctlProcess.standardError = simctlPipe
            
            simctlProcess.terminationHandler = { process in
                let success = process.terminationStatus == 0
                print("xcrun simctl help exit code: \(process.terminationStatus)")
                completion(success)
            }
            
            try simctlProcess.run()
        } catch {
            print("Failed to run xcrun simctl help: \(error)")
            completion(false)
        }
    }
    
    func getInstallInstructions() -> (xcode: String, commandLineTools: String) {
        let xcodeInstructions = """
        To install Xcode:
        1. Open the App Store
        2. Search for "Xcode"
        3. Click "Install" or "Get"
        4. Wait for the installation to complete
        
        Alternatively, download from Apple Developer Portal:
        https://developer.apple.com/xcode/
        """
        
        let cltInstructions = """
        To install Xcode Command Line Tools:
        1. Open Terminal
        2. Run: xcode-select --install
        3. Click "Install" in the popup dialog
        4. Wait for installation to complete
        
        Or install via Xcode:
        Xcode → Preferences → Locations → Command Line Tools
        """
        
        return (xcode: xcodeInstructions, commandLineTools: cltInstructions)
    }
}
