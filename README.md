# SimFiles - iOS Simulator Files Manager

A beautiful native macOS app that allows you to manage files in the iOS Simulator's Files app storage. Copy, move, delete, and organize files directly from your Mac.

## Features

- **Simulator Detection**: Automatically detects booted iOS simulators
- **File Browser**: Modern grid-based file browser with file icons and metadata
- **Drag & Drop**: Drag files from Finder directly into the simulator's Files app
- **File Operations**: Create folders, delete files, and manage simulator storage
- **Modern UI**: Beautiful macOS design with SwiftUI

## Requirements

- macOS 14.0 or later
- Xcode (for iOS Simulator)

## How to Use

1. **Launch iOS Simulator**: Start Xcode and run any iOS simulator
2. **Open SimFiles app**: Launch the SimFiles app
3. **Select Simulator**: Choose a booted simulator from the sidebar
4. **Manage Files**: 
   - Browse files in the simulator's Files app storage
   - Drag files from Finder to copy them to the simulator
   - Create new folders using the "New Folder" button
   - Select files and delete them using the "Delete" button
   - Double-click folders to navigate into them
   - Use the back button to navigate to parent directories

## Technical Details

The app works by:

1. Running `xcrun simctl listapps booted` to find running simulators
2. Extracting the DocumentsApp (Files app) information from each simulator
3. Finding the LocalStorage path: `GroupContainers["group.com.apple.FileProvider.LocalStorage"]`
4. Providing a native macOS interface to manage files in that directory

## Building from Source

1. Open `SimFiles.xcodeproj` in Xcode
2. Build and run (⌘+R)

## File Structure

```
SimFiles/
├── SimFilesApp.swift          # Main app entry point
├── ContentView.swift          # Main UI with simulator selection and file browser
├── SimulatorManager.swift     # Handles simulator detection and xcrun simctl integration
├── FileManager.swift          # File operations (copy, delete, create folders)
└── Assets.xcassets           # App assets and icons
```

## Limitations

- Only works with booted iOS simulators
- Requires the Files app to be available on the simulator
- File operations are limited to the Files app's LocalStorage container

## License

This project is provided as-is for educational and development purposes.