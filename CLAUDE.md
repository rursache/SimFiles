# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SimFiles is a native macOS app (SwiftUI) for managing files in iOS Simulator's Files app storage. It detects booted simulators via `xcrun simctl`, locates the Files app's LocalStorage container, and provides a grid-based file browser with drag-and-drop from Finder.

## Build Commands

```bash
# Build (resolve packages first on clean checkout)
xcodebuild -project SimFiles.xcodeproj -scheme SimFiles -destination 'platform=macOS' build

# Clean build
xcodebuild -project SimFiles.xcodeproj -scheme SimFiles clean build
```

No test target exists.

## Architecture

The app uses SwiftUI with ObservableObject-based state management (MVVM-lite):

- **App.swift** — Entry point. Fixed 1024x600 non-resizable window.
- **ContentView.swift** — NavigationSplitView with simulator sidebar + file detail area. Owns three `@StateObject` managers.
- **SimulatorManager.swift** — Runs `xcrun simctl list devices booted --json` and `xcrun simctl listapps` to discover simulators and their Files app LocalStorage paths. Parses plist output via `PropertyListSerialization`.
- **SimFilesFileManager.swift** (in FileManager.swift) — Named `SimFilesFileManager` to avoid Foundation collision. Handles file CRUD, clipboard (custom pasteboard type `ro.randusoft.simfiles.clipboard-operation`), and uses FileMonitor for live directory watching.
- **SystemRequirements.swift** — Validates Xcode, Command Line Tools, and `xcrun simctl` availability at launch.

UI components: **FileGridView** (LazyVGrid, 6 columns at 120pt), **FileItemView** (icon + metadata + context menu), **SimulatorRow** (simulator list entry).

## Dependencies (Swift Package Manager)

| Package | Purpose |
|---------|---------|
| [SwiftUI Introspect](https://github.com/siteline/swiftui-introspect) ≥26.0.0 | Access NSSplitViewController for sidebar customization |
| [FileMonitor](https://github.com/aus-der-Technik/FileMonitor) ≥1.2.1 | Watch file system changes in simulator storage |

## Key Details

- **Platform**: macOS 14.0+ (Sonoma), Swift 5, SwiftUI
- **Bundle ID**: `ro.randusoft.SimFiles`
- **Sandbox**: Disabled (needs direct file system and xcrun access)
- **Signing**: Apple Development, Team 3999533L99
- **Data models**: `Simulator` (id, name, os, localStoragePath) and `FileItem` (name, path, isDirectory, size, dateModified, computed icon/formattedSize)
