//
//  SimulatorRow.swift
//  SimFiles
//
//  Created by Radu Ursache on 24.08.2025.
//

import SwiftUI

struct SimulatorRow: View {
    let simulator: Simulator
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(simulator.localStoragePath != nil ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: deviceIcon)
                        .foregroundColor(simulator.localStoragePath != nil ? .green : .orange)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text("\(simulator.name) (\(simulator.os))")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        ).contentShape(.rect(cornerRadius: 8))
    }
    
    private var deviceIcon: String {
        let deviceName = simulator.name.lowercased()
        
        if deviceName.contains("iphone") {
            return "iphone"
        } else if deviceName.contains("ipad") {
            return "ipad"
        } else if deviceName.contains("tv") {
            return "appletv"
        } else if deviceName.contains("watch") {
            return "applewatch"
        } else if deviceName.contains("vision") {
            return "vision.pro"
        } else {
            return "ipad.landscape.and.iphone"
        }
    }
}
