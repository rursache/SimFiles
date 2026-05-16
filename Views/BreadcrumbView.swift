import SwiftUI

struct BreadcrumbView: View {
    let rootPath: String
    let currentPath: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                Button {
                    onSelect(segment.path)
                } label: {
                    HStack(spacing: 6) {
                        if index == 0 {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.tint)
                        }
                        Text(segment.name)
                            .font(.system(size: 13, weight: index == segments.count - 1 ? .semibold : .regular))
                            .foregroundStyle(index == segments.count - 1 ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(index == segments.count - 1)
            }
        }
    }

    private var segments: [(name: String, path: String)] {
        guard !rootPath.isEmpty, currentPath.hasPrefix(rootPath) else { return [] }

        let rootName = URL(fileURLWithPath: rootPath).lastPathComponent
        var result: [(String, String)] = [(rootName, rootPath)]

        let relative = String(currentPath.dropFirst(rootPath.count))
        let components = relative.split(separator: "/").map(String.init).filter { !$0.isEmpty }

        var running = rootPath
        for component in components {
            running = (running as NSString).appendingPathComponent(component)
            result.append((component, running))
        }

        return result
    }
}
