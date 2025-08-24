import Foundation

struct Simulator: Identifiable, Equatable {
    let id: String
    let name: String
    let os: String
    let localStoragePath: String?
}

class SimulatorManager: ObservableObject {
    @Published var simulators: [Simulator] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadSimulators() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let bootedSimulators = try await getBootedSimulators()
                let simulatorsWithPaths = try await getFilesAppPaths(for: bootedSimulators)
                
                await MainActor.run {
                    self.simulators = simulatorsWithPaths
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
    
    private func getBootedSimulators() async throws -> [Simulator] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "booted", "--json"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SimulatorError.invalidResponse
        }
        
        guard let devices = jsonObject["devices"] as? [String: Any] else {
            throw SimulatorError.invalidResponse
        }
        
        var simulators: [Simulator] = []
        
        for (runtime, deviceList) in devices {
            if let deviceArray = deviceList as? [[String: Any]] {
                for device in deviceArray {
                    if let name = device["name"] as? String, let udid = device["udid"] as? String {
                        simulators.append(Simulator(
                            id: udid,
                            name: name,
                            os: formatRuntime(runtime),
                            localStoragePath: nil
                        ))
                    }
                }
            }
        }
        
        return simulators
    }
    
    private func getFilesAppPaths(for simulators: [Simulator]) async throws -> [Simulator] {
        var updatedSimulators: [Simulator] = []
        
        for simulator in simulators {
            let appsData = try await getSimulatorApps(simulator)
            let path = extractFilesAppPath(from: appsData, deviceId: simulator.id)
            updatedSimulators.append(Simulator(
                id: simulator.id,
                name: simulator.name,
                os: simulator.os,
                localStoragePath: path
            ))
        }
        
        return updatedSimulators
    }
    
    private func getSimulatorApps(_ simulator: Simulator) async throws -> [String: Any] {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "listapps", "\(simulator.id)"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                
                do {
                    guard let plistObject = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                        print("Failed to parse plist data from 'xcrun simctl listapps booted'")
                        continuation.resume(returning: [:])
                        return
                    }
                    
                    print("Successfully parsed apps data from booted simulators")
                    continuation.resume(returning: plistObject)
                    
                } catch {
                    print("Error parsing plist from 'xcrun simctl listapps booted': \(error)")
                    continuation.resume(returning: [:])
                }
            }
            
            do {
                try process.run()
            } catch {
                print("Failed to run 'xcrun simctl listapps booted': \(error)")
                continuation.resume(returning: [:])
            }
        }
    }
    
    private func extractFilesAppPath(from appsData: [String: Any], deviceId: String) -> String? {
        guard let documentsApp = appsData["com.apple.DocumentsApp"] as? [String: Any] else {
            print("DocumentsApp not found in apps data")
            return nil
        }
        
        guard let groupContainers = documentsApp["GroupContainers"] as? [String: Any] else {
            print("GroupContainers not found in DocumentsApp")
            return nil
        }
        
        guard let localStorageURL = groupContainers["group.com.apple.FileProvider.LocalStorage"] as? String else {
            print("LocalStorage path not found in GroupContainers")
            return nil
        }
        
        let cleanPath = localStorageURL.replacingOccurrences(of: "file://", with: "")
        let fileProviderStoragePath = URL(fileURLWithPath: cleanPath).appendingPathComponent("File Provider Storage").path
        print("Found File Provider Storage path: \(fileProviderStoragePath) for \(deviceId)")
        return fileProviderStoragePath
    }
    
    private func formatRuntime(_ input: String) -> String {
        guard let cleanRuntime = input.split(separator: ".").last else {
            return input
        }
        let parts = cleanRuntime.split(separator: "-")
        
        guard parts.count >= 2 else {
            return input
        }
        
        return "\(parts[0]) \(parts.dropFirst().joined(separator: "."))"
    }
}

enum SimulatorError: Error, LocalizedError {
    case invalidResponse
    case filesAppNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from xcrun simctl"
        case .filesAppNotFound:
            return "Files app not found on simulator"
        }
    }
}
