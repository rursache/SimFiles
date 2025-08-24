import SwiftUI

@main
struct SimFilesApp: App {
    private let appFrame = CGSize(width: 1024, height: 600)
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: appFrame.width, minHeight: appFrame.height)
                .frame(width: appFrame.width, height: appFrame.height)
        }.windowResizability(.contentSize)
    }
}
