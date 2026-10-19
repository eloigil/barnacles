import AppKit

struct BarnacleError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Everything Barnacles knows about Orca itself.
///
/// Orca allows one running instance per profile (its userData folder). Starting
/// it with `--user-data-dir=<folder>` gives it a separate profile, so several
/// instances can run side by side.
enum Orca {
    static let bundleID = "com.stablyai.orca"
    static let website = URL(string: "https://www.onorca.dev")!
    static let userDataFlag = "--user-data-dir="

    static var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    /// The profile the normal Orca uses.
    static var mainProfile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/orca", isDirectory: true)
    }

    static func launch(profile: URL) async throws {
        guard let appURL else { throw BarnacleError("Orca isn't installed.") }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.activates = true
        config.arguments = [userDataFlag + profile.path]
        _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }

    /// Running Orca instances that were started with a custom profile, keyed by
    /// that profile's path.
    static func runningByProfile() -> [String: NSRunningApplication] {
        var result: [String: NSRunningApplication] = [:]
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            guard isAlive(app),
                  let arg = arguments(of: app.processIdentifier).first(where: { $0.hasPrefix(userDataFlag) })
            else { continue }
            result[normalize(String(arg.dropFirst(userDataFlag.count)))] = app
        }
        return result
    }

    /// Asks the kernel rather than trusting `isTerminated`, which only updates
    /// while the main run loop gets to process notifications.
    static func isAlive(_ app: NSRunningApplication) -> Bool {
        kill(app.processIdentifier, 0) == 0 || errno == EPERM
    }

    static func normalize(_ path: String) -> String {
        var p = path
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// Command-line arguments of another process (same user), via KERN_PROCARGS2.
    static func arguments(of pid: pid_t) -> [String] {
        var argmax: Int32 = 0
        var argmaxSize = MemoryLayout<Int32>.size
        var argmaxMib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        guard sysctl(&argmaxMib, 2, &argmax, &argmaxSize, nil, 0) == 0, argmax > 0 else { return [] }

        var buffer = [UInt8](repeating: 0, count: Int(argmax))
        var size = buffer.count
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }

        // Layout: argc, executable path, padding NULs, then argc NUL-terminated args.
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var i = MemoryLayout<Int32>.size
        while i < size && buffer[i] != 0 { i += 1 }
        while i < size && buffer[i] == 0 { i += 1 }

        var args: [String] = []
        while args.count < argc && i < size {
            let start = i
            while i < size && buffer[i] != 0 { i += 1 }
            args.append(String(decoding: buffer[start..<i], as: UTF8.self))
            i += 1
        }
        return args
    }

    // MARK: Settings

    /// The settings file of a profile: profiles/<active profile id>/orca-data.json.
    static func dataFile(in profile: URL) -> URL {
        var profileID = "local-default"
        let index = profile.appendingPathComponent("orca-profile-index.json")
        if let data = try? Data(contentsOf: index),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let active = json["activeProfileId"] as? String, !active.isEmpty {
            profileID = active
        }
        return profile.appendingPathComponent("profiles/\(profileID)/orca-data.json")
    }

    static func hasSettings(_ profile: URL) -> Bool {
        FileManager.default.fileExists(atPath: dataFile(in: profile).path)
    }

    /// UI state tied to one instance's own repos, panes, windows and update checks.
    private static let localUIKeys =
        "Repo|repo[A-Z]|PaneKey|[Ww]orktreeId|lastActive|collapsedGroups|activeView"
        + "|HostIds|HostOrder|windowMaximized|UpdateCheck|UpdateVersion"

    /// Copies preferences, onboarding and non-project UI state from one profile
    /// into another. Projects, workspaces and sessions are left alone. The
    /// target must not be running, or Orca will write its old settings back.
    static func copySettings(from source: URL, to target: URL) throws {
        let fm = FileManager.default
        let sourceFile = dataFile(in: source)
        guard let sourceData = try? Data(contentsOf: sourceFile),
              let src = try? JSONSerialization.jsonObject(with: sourceData) as? [String: Any]
        else { throw BarnacleError("Couldn't read your Orca settings.") }

        let targetFile = dataFile(in: target)
        var dst: [String: Any] = ["schemaVersion": src["schemaVersion"] ?? 1]
        if let data = try? Data(contentsOf: targetFile) {
            guard let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BarnacleError("This barnacle's settings file is damaged.")
            }
            dst = existing
            let backup = targetFile.appendingPathExtension("barnacles-bak")
            try? fm.removeItem(at: backup)
            try fm.copyItem(at: targetFile, to: backup)
        }

        var ui = dst["ui"] as? [String: Any] ?? [:]
        for (key, value) in src["ui"] as? [String: Any] ?? [:]
        where key.range(of: localUIKeys, options: .regularExpression) == nil {
            ui[key] = value
        }
        dst["settings"] = src["settings"] ?? [:]
        dst["onboarding"] = src["onboarding"] ?? [:]
        dst["ui"] = ui

        try fm.createDirectory(at: targetFile.deletingLastPathComponent(),
                               withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        let out = try JSONSerialization.data(withJSONObject: dst, options: [.prettyPrinted, .withoutEscapingSlashes])
        try out.write(to: targetFile, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: targetFile.path)
    }
}
