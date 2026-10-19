import AppKit
import SwiftUI

enum BarnacleColor: String, CaseIterable, Codable, Identifiable {
    case blue, teal, green, yellow, orange, red, pink, purple

    var id: String { rawValue }
    var color: Color { Color(nsColor: nsColor) }
    var nsColor: NSColor {
        switch self {
        case .blue: .systemBlue
        case .teal: .systemTeal
        case .green: .systemGreen
        case .yellow: .systemYellow
        case .orange: .systemOrange
        case .red: .systemRed
        case .pink: .systemPink
        case .purple: .systemPurple
        }
    }
}

struct Barnacle: Identifiable, Hashable {
    /// Folder name under ~/.barnacles. Short and ASCII-only on purpose.
    let id: String
    var name: String
    var color: BarnacleColor
    let folder: URL
}

/// Barnacles live in ~/.barnacles/<id>, one Orca profile each (shared with the
/// `barnacles` command-line tool). Names and colors are kept in
/// ~/.barnacles/barnacles.json.
@MainActor
final class BarnacleStore: ObservableObject {
    @Published private(set) var barnacles: [Barnacle] = []
    @Published private(set) var running: [String: NSRunningApplication] = [:]
    @Published private(set) var busy: Set<String> = []
    @Published private(set) var orcaInstalled = true
    @Published var showingNewSheet = false
    @Published var errorMessage: String?

    // Orca creates Unix sockets inside the profile folder, and macOS caps
    // socket paths at 103 bytes, so the folder path has to stay short.
    private static let maxFolderPathLength = 103 - 32

    let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".barnacles", isDirectory: true)
    private var metadataURL: URL { root.appendingPathComponent("barnacles.json") }

    private struct Metadata: Codable {
        var name: String
        var color: BarnacleColor
    }

    init() {
        refresh()
        for barnacle in barnacles { Launcher.refreshIfPresent(for: barnacle) }
    }

    var mainOrcaHasSettings: Bool { Orca.hasSettings(Orca.mainProfile) }

    func isRunning(_ b: Barnacle) -> Bool { running[b.id] != nil }
    func isBusy(_ b: Barnacle) -> Bool { busy.contains(b.id) }

    // MARK: Loading

    func refresh() {
        orcaInstalled = Orca.appURL != nil
        let meta = loadMetadata()
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []

        let list = folders.compactMap { url -> Barnacle? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
            let id = url.lastPathComponent
            let m = meta[id]
            return Barnacle(id: id, name: m?.name ?? id, color: m?.color ?? defaultColor(for: id), folder: url)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if list != barnacles { barnacles = list }

        let byPath = Orca.runningByProfile()
        var now: [String: NSRunningApplication] = [:]
        for b in list {
            if let app = byPath[Orca.normalize(b.folder.path)] { now[b.id] = app }
        }
        if now != running { running = now }
    }

    private func loadMetadata() -> [String: Metadata] {
        guard let data = try? Data(contentsOf: metadataURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Metadata].self, from: data)) ?? [:]
    }

    private func saveMetadata(_ meta: [String: Metadata]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(meta).write(to: metadataURL, options: .atomic)
    }

    private func defaultColor(for id: String) -> BarnacleColor {
        let all = BarnacleColor.allCases
        return all[id.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) } % all.count]
    }

    // MARK: Creating

    /// Returns a problem with the name, or nil if it's fine.
    func nameProblem(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "Give your barnacle a name." }
        if name.count > 30 { return "That name is a bit long. Try something shorter." }
        if barnacles.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return "You already have a barnacle called \u{201C}\(name)\u{201D}."
        }
        return nil
    }

    @discardableResult
    func create(name raw: String, color: BarnacleColor, copySettings: Bool) throws -> Barnacle {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let problem = nameProblem(name) { throw BarnacleError(problem) }

        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let budget = Self.maxFolderPathLength - root.path.count - 1
        guard budget >= 4 else {
            throw BarnacleError("Your home folder's path is too long for Orca to run extra copies.")
        }
        let base = String(Self.folderName(for: name).prefix(min(24, budget - 3)))
        var id = base
        var n = 2
        while fm.fileExists(atPath: root.appendingPathComponent(id).path) {
            id = "\(base)-\(n)"
            n += 1
        }

        let folder = root.appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false,
                               attributes: [.posixPermissions: 0o700])
        let barnacle = Barnacle(id: id, name: name, color: color, folder: folder)

        var meta = loadMetadata()
        meta[id] = Metadata(name: name, color: color)
        try saveMetadata(meta)

        if copySettings && mainOrcaHasSettings {
            try Orca.copySettings(from: Orca.mainProfile, to: folder)
        }
        // The launcher is a convenience; the barnacle works without it.
        _ = try? Launcher.write(for: barnacle)

        refresh()
        return barnacle
    }

    /// "Side Project!" -> "side-project"
    static func folderName(for name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        var out = ""
        for scalar in folded.unicodeScalars {
            if scalar.isASCII, CharacterSet.alphanumerics.contains(scalar) {
                out.unicodeScalars.append(scalar)
            } else if !out.isEmpty && !out.hasSuffix("-") {
                out += "-"
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "barnacle" : out
    }

    // MARK: Actions

    func open(_ b: Barnacle) {
        if let app = running[b.id] {
            app.unhide()
            app.activate()
            return
        }
        Task {
            await withBusy(b) {
                try await Orca.launch(profile: b.folder)
                // Give Orca a moment to show up so the status flips to "Running".
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(250))
                    refresh()
                    if isRunning(b) { break }
                }
            }
        }
    }

    func quit(_ b: Barnacle) {
        guard let app = running[b.id] else { return }
        Task {
            await withBusy(b) { try await quitAndWait(app, name: b.name) }
        }
    }

    func resetSettings(_ b: Barnacle) {
        Task {
            await withBusy(b) {
                let wasRunning = running[b.id]
                if let app = wasRunning { try await quitAndWait(app, name: b.name) }
                try Orca.copySettings(from: Orca.mainProfile, to: b.folder)
                if wasRunning != nil { try await Orca.launch(profile: b.folder) }
            }
        }
    }

    func delete(_ b: Barnacle) {
        Task {
            await withBusy(b) {
                if let app = running[b.id] { try await quitAndWait(app, name: b.name) }
                try FileManager.default.trashItem(at: b.folder, resultingItemURL: nil)
                Launcher.remove(for: b)
                var meta = loadMetadata()
                meta[b.id] = nil
                try saveMetadata(meta)
            }
        }
    }

    func revealLauncher(_ b: Barnacle) {
        var url = Launcher.url(forName: b.name)
        if !FileManager.default.fileExists(atPath: url.path) {
            do { url = try Launcher.write(for: b) } catch {
                errorMessage = "Couldn't create the launcher: \(error.localizedDescription)"
                return
            }
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func quitAndWait(_ app: NSRunningApplication, name: String) async throws {
        app.terminate()
        for _ in 0..<60 where Orca.isAlive(app) {
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard !Orca.isAlive(app) else {
            throw BarnacleError("\u{201C}\(name)\u{201D} didn't quit. Check its window for a question, then try again.")
        }
    }

    private func withBusy(_ b: Barnacle, _ work: () async throws -> Void) async {
        busy.insert(b.id)
        defer {
            busy.remove(b.id)
            refresh()
        }
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
