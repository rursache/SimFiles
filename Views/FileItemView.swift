import SwiftUI
import Foundation

struct FileItemView: View {
    let file: FileItem
    let isSelected: Bool
    let onDoubleClick: () -> Void
    let onSelectionChange: (Bool) -> Void
    let onCopyFile: () -> Void
    let onCutFile: () -> Void
    let onRenameFile: () -> Void
    let onDeleteFile: () -> Void

    @State private var tapCount = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background.secondary)
                    .frame(width: 64, height: 64)

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

                Text(file.isDirectory ? " " : file.formattedSize)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(height: 12)
            }
        }
        .frame(width: 120, height: 124)
        .padding(.vertical, 6)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.18))
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
            }
        }
        .contentShape(.rect(cornerRadius: 12))
        .onDrag {
            NSItemProvider(object: URL(fileURLWithPath: file.path) as NSURL)
        }
        .onTapGesture {
            tapCount += 1
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                tapCount = 0
            }
        }
        .contextMenu {
            if file.isDirectory {
                Button("Open", systemImage: "folder") { onDoubleClick() }
            }
            Button("Copy", systemImage: "doc.on.doc") { onCopyFile() }
            Button("Cut", systemImage: "scissors") { onCutFile() }
            Button("Rename", systemImage: "pencil") { onRenameFile() }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { onDeleteFile() }
        }
        .onChange(of: tapCount) { _, newValue in
            if newValue == 1 {
                onSelectionChange(true)
            } else if newValue == 2 {
                onDoubleClick()
            }
        }
    }
}
