# CLAUDE.md

## Overview
SimFiles is a native macOS SwiftUI app for managing files in the iOS Simulator's Files app storage, using `xcrun simctl` to discover booted simulators and locate the Files app `LocalStorage` container, then exposing a grid browser with Finder drag-and-drop

## Build
```bash
xcodebuild -project SimFiles.xcodeproj -scheme SimFiles -destination 'platform=macOS' build
```
No test target

## Folder layout
The four top-level folders (`App/`, `Models/`, `Managers/`, `Views/`) are `PBXFileSystemSynchronizedRootGroup` references, so any new `.swift` dropped in is auto-included in the target without a pbxproj edit

- `App/`: `SimFilesApp` entry, `ContentView` (state owner and all alerts)
- `Models/`: `FileItem`, `FileSortOrder`, `FileError`, `PendingOverwrite`, `Simulator`, `SimulatorError`
- `Managers/`: `SimFilesFileManager` (CRUD, clipboard, live watching via `FileMonitor`), `SimulatorManager` (xcrun shelling), `SystemRequirements`
- `Views/`: `SidebarView`, `SimulatorRow`, `FileBrowserView` (detail panel and toolbar), `FileGridView`, `FileItemView`, `BreadcrumbView`

## Key details
- Platform: macOS 26.0+ (Tahoe), SwiftUI with Liquid Glass
- Bundle ID `ro.randusoft.SimFiles`, Team `3999533L99`, sandbox disabled (needs `xcrun` and direct file access)
- `SimFilesFileManager` is named that way to avoid colliding with `Foundation.FileManager`
- Custom clipboard pasteboard type: `ro.randusoft.simfiles.clipboard-operation`
- Build number is sourced from `SupportiveFiles/build.xcconfig` and auto-incremented each build by the `Increment Build Number` script phase; `MARKETING_VERSION` is in target build settings

## Dependency
- [FileMonitor](https://github.com/aus-der-Technik/FileMonitor) ≥1.2.1 for live directory watching
