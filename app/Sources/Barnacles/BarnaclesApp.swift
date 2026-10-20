import AppKit
import SwiftUI

/// Barnacles' own source repository, for the "Star on GitHub" buttons.
enum GitHub {
    static let repo = URL(string: "https://github.com/eloigil/barnacles")!
}

@main
struct BarnaclesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BarnacleStore.shared

    var body: some Scene {
        Window("Barnacles", id: "main") {
            ContentView()
                .environmentObject(store)
                .background(WindowOpenerCapture())
        }
        .defaultSize(width: 820, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Orca Window") { store.newWindow() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(!store.orcaInstalled)
                Button("New Barnacle…") { store.showingNewSheet = true }
                    .keyboardShortcut("n")
                    .disabled(!store.orcaInstalled)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opens the main window from AppKit code; set once SwiftUI is up.
    static var openMainWindow: (() -> Void)?

    private var dockMenu: NSMenu?

    // Keep running with no window open, so the Dock menu keeps working.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { Self.openMainWindow?() }
        return true
    }

    /// Right-click on Barnacles in the Dock: a new Orca window, or one of your barnacles.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let store = BarnacleStore.shared
        store.refresh()

        let menu = NSMenu()
        let newItem = ActionMenuItem("New Orca Window") { [weak self] in self?.newWindow() }
        newItem.isEnabled = store.orcaInstalled
        menu.addItem(newItem)

        if !store.barnacles.isEmpty {
            menu.addItem(.separator())
            for barnacle in store.barnacles {
                let item = ActionMenuItem(barnacle.name) { store.open(barnacle) }
                item.image = Self.dot(barnacle.color.nsColor)
                item.state = store.isRunning(barnacle) ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let star = ActionMenuItem("Star Barnacles on GitHub") { NSWorkspace.shared.open(GitHub.repo) }
        star.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil)
        menu.addItem(star)

        dockMenu = menu
        return menu
    }

    private func newWindow() {
        let store = BarnacleStore.shared
        guard store.newWindow() == nil, let message = store.errorMessage else { return }
        // With the window open, its own alert shows the error.
        guard !NSApp.windows.contains(where: { $0.isVisible }) else { return }
        store.errorMessage = nil
        let alert = NSAlert()
        alert.messageText = "Couldn't open a new Orca window"
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }

    private static func dot(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5)).fill()
            return true
        }
    }
}

/// An NSMenuItem that runs a closure.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}

/// Hands SwiftUI's openWindow action to the app delegate, so clicking the
/// Dock icon can bring the window back after it was closed.
private struct WindowOpenerCapture: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear.onAppear {
            AppDelegate.openMainWindow = { openWindow(id: "main") }
        }
    }
}
