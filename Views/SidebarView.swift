import SwiftUI

struct SidebarView: View {
    @ObservedObject var systemRequirements: SystemRequirements
    @ObservedObject var simulatorManager: SimulatorManager
    @ObservedObject var fileManager: SimFilesFileManager
    @Binding var selectedSimulator: Simulator?

    var body: some View {
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
}
