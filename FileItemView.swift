//
//  FileItemView.swift
//  SimFiles
//
//  Created by Radu Ursache on 24.08.2025.
//

import SwiftUI
import Foundation

struct FileItemView: View {
    let file: FileItem
    let isSelected: Bool
    let onDoubleClick: () -> Void
    let onSelectionChange: (Bool) -> Void
    let onCopyFile: () -> Void
    let onCutFile: () -> Void
    let onDeleteFile: () -> Void
    
    @State private var tapCount = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 60, height: 60)
                
                Image(nsImage: file.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
            }
            
            VStack(spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
                    .padding(.horizontal, 4)
                
                Group {
                    if file.isDirectory {
                        Text(" ")
                            .font(.system(size: 10))
                            .foregroundColor(.clear)
                    } else {
                        Text(file.formattedSize)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }.frame(height: 12)
            }
        }
        .frame(width: 120, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 2)
        ).onDrag {
            let fileURL = URL(fileURLWithPath: file.path)
            return NSItemProvider(object: fileURL as NSURL)
        }.onTapGesture {
            tapCount += 1
            
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                tapCount = 0
            }
        }.contextMenu {
            if file.isDirectory {
                Button("Open") {
                    onDoubleClick()
                }
            }

            Button("Copy") {
                onCopyFile()
            }

            Button("Cut") {
                onCutFile()
            }

            Button("Delete") {
                onDeleteFile()
            }
        }.onChange(of: tapCount) { _, newValue in
            if newValue == 1 {
                onSelectionChange(true)
            } else if newValue == 2 {
                onDoubleClick()
            }
        }
    }
}
