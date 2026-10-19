import AppKit
import SwiftUI

@main
struct BarnaclesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BarnacleStore()

    var body: some Scene {
        Window("Barnacles", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 560, height: 440)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Barnacle…") { store.showingNewSheet = true }
                    .keyboardShortcut("n")
                    .disabled(!store.orcaInstalled)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
