import Combine
import SwiftUI

/// What the sidebar has selected.
enum SidebarItem: Hashable {
    case overview
    case barnacle(String)
}

struct ContentView: View {
    @EnvironmentObject private var store: BarnacleStore
    @State private var selection: SidebarItem? = .overview
    @State private var pendingDelete: Barnacle?
    @State private var pendingReset: Barnacle?

    private let ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 300)
        } detail: {
            detail
        }
        .navigationTitle("")
        .frame(minWidth: 720, minHeight: 480)
        .sheet(isPresented: $store.showingNewSheet) {
            NewBarnacleSheet { selection = .barnacle($0.id) }
        }
        .alert(item: $pendingDelete) { barnacle in
            Alert(
                title: Text("Delete \u{201C}\(barnacle.name)\u{201D}?"),
                message: Text((store.isRunning(barnacle) ? "It will be closed first. " : "")
                    + "Its project list, sessions and settings go to the Trash. Your code and repositories aren't touched."),
                primaryButton: .destructive(Text("Move to Trash")) {
                    selection = .overview
                    store.delete(barnacle)
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $pendingReset) { barnacle in
            Alert(
                title: Text("Copy settings from your Orca?"),
                message: Text("\u{201C}\(barnacle.name)\u{201D} will get the same theme, agents and preferences as your main Orca. Its projects stay as they are."
                    + (store.isRunning(barnacle) ? " It will restart." : "")),
                primaryButton: .default(Text("Copy Settings")) { store.resetSettings(barnacle) },
                secondaryButton: .cancel()
            )
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onReceive(ticker) { _ in store.refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            store.refresh()
        }
    }

    @ViewBuilder private var detail: some View {
        if !store.orcaInstalled {
            OrcaMissingView()
        } else if case .barnacle(let id) = selection, let barnacle = store.barnacles.first(where: { $0.id == id }) {
            BarnacleDetail(barnacle: barnacle,
                           onReset: { pendingReset = barnacle },
                           onDelete: { pendingDelete = barnacle })
                .id(barnacle.id)
        } else {
            OverviewView(selection: $selection)
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject private var store: BarnacleStore
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label {
                Text("All Barnacles")
            } icon: {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 22, height: 22)
            }
            .tag(SidebarItem.overview)

            if !store.barnacles.isEmpty {
                Section("Barnacles") {
                    ForEach(store.barnacles) { barnacle in
                        HStack {
                            Label {
                                Text(barnacle.name).lineLimit(1)
                            } icon: {
                                IconTile(barnacle: barnacle, size: 22)
                            }
                            Spacer()
                            if store.isRunning(barnacle) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 7, height: 7)
                                    .help("Running")
                            }
                        }
                        .tag(SidebarItem.barnacle(barnacle.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.showingNewSheet = true
            } label: {
                Label("New Barnacle", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(!store.orcaInstalled)
            .padding(12)
        }
    }
}

// MARK: - Building blocks

/// A System Settings–style icon: rounded tile with a gradient and a white
/// glyph or initial.
struct IconTile: View {
    var color: Color
    var symbol: String?
    var text: String?
    var size: CGFloat = 22

    init(color: Color, symbol: String, size: CGFloat = 22) {
        self.color = color
        self.symbol = symbol
        self.size = size
    }

    init(barnacle: Barnacle, size: CGFloat = 22) {
        self.color = barnacle.color.color
        self.text = String(barnacle.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
        self.size = size
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(color.gradient)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.52, weight: .semibold))
                        .foregroundStyle(.white)
                } else if let text {
                    Text(text)
                        .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
    }
}

/// The big card at the top of each page: icon, title, description, and a
/// soft gradient tinted with `tint`.
struct HeroCard<Actions: View>: View {
    let image: NSImage
    let title: String
    let subtitle: String
    let tint: Color
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: image)
                .resizable()
                .frame(width: 84, height: 84)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .fixedSize(horizontal: false, vertical: true)
            actions()
                .padding(.top, 6)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.fill.quaternary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [tint.opacity(0.32), tint.opacity(0.10), .clear],
                                             startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.06))
                )
        }
    }
}

/// A rounded group of rows separated by inset dividers, like System Settings.
struct RowGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            _VariadicView.Tree(DividedLayout()) { content() }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.fill.quaternary)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private struct DividedLayout: _VariadicView_MultiViewRoot {
        func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id
            ForEach(children) { child in
                child
                if child.id != last {
                    Divider().padding(.leading, 50).padding(.trailing, 14)
                }
            }
        }
    }
}

/// One row in a `RowGroup`: icon tile, title, and whatever goes on the right.
struct SettingsRow<Trailing: View>: View {
    let icon: IconTile
    let title: String
    var destructive = false
    var action: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing
    @State private var hovering = false

    var body: some View {
        let row = HStack(spacing: 12) {
            icon
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(destructive ? Color.red : Color.primary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
                .background(hovering ? Color.primary.opacity(0.05) : .clear)
                .onHover { hovering = $0 }
        } else {
            row
        }
    }
}

extension SettingsRow where Trailing == AnyView {
    /// A clickable row with a chevron.
    init(icon: IconTile, title: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.init(icon: icon, title: title, destructive: destructive, action: action) {
            AnyView(Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary))
        }
    }
}

struct StatusLabel: View {
    let running: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(running ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 7, height: 7)
            Text(running ? "Running" : "Not running")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

/// Scrollable page with the standard padding.
struct Page<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 18) { content() }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Overview

struct OverviewView: View {
    @EnvironmentObject private var store: BarnacleStore
    @Binding var selection: SidebarItem?

    var body: some View {
        Page {
            HeroCard(
                image: NSApp.applicationIconImage,
                title: "Barnacles",
                subtitle: "Run more than one Orca at a time. Each barnacle is its own Orca window, with its own projects and sessions.",
                tint: .teal
            ) {
                if store.barnacles.isEmpty {
                    Button("Create Your First Barnacle") { store.showingNewSheet = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }

            if !store.barnacles.isEmpty {
                RowGroup {
                    ForEach(store.barnacles) { barnacle in
                        SettingsRow(icon: IconTile(barnacle: barnacle, size: 24), title: barnacle.name,
                                    action: { selection = .barnacle(barnacle.id) }) {
                            HStack(spacing: 10) {
                                StatusLabel(running: store.isRunning(barnacle))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            RowGroup {
                SettingsRow(icon: IconTile(color: .blue, symbol: "plus", size: 24), title: "New Barnacle\u{2026}") {
                    store.showingNewSheet = true
                }
            }

            Text("Tip: open a barnacle from Spotlight by typing \u{201C}Orca\u{201D} and its name.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }
}

// MARK: - Barnacle page

struct BarnacleDetail: View {
    @EnvironmentObject private var store: BarnacleStore
    let barnacle: Barnacle
    let onReset: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let running = store.isRunning(barnacle)
        let busy = store.isBusy(barnacle)

        Page {
            HeroCard(
                image: Launcher.icon(for: barnacle),
                title: barnacle.name,
                subtitle: running
                    ? "Running now, with its own projects and sessions."
                    : "A separate Orca with its own projects and sessions.",
                tint: barnacle.color.color
            ) {
                HStack(spacing: 10) {
                    Button(running ? "Show Window" : "Open") { store.open(barnacle) }
                        .buttonStyle(.borderedProminent)
                        .tint(barnacle.color.color)
                    if running {
                        Button("Quit") { store.quit(barnacle) }
                    }
                    if busy {
                        ProgressView().controlSize(.small)
                    }
                }
                .controlSize(.large)
                .disabled(busy)
            }

            RowGroup {
                SettingsRow(icon: IconTile(color: running ? .green : .gray, symbol: "power", size: 24),
                            title: "Status") {
                    StatusLabel(running: running)
                }
                SettingsRow(icon: IconTile(color: .gray, symbol: "magnifyingglass", size: 24),
                            title: "Spotlight name") {
                    Text("Orca \(barnacle.name)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            RowGroup {
                SettingsRow(icon: IconTile(color: .blue, symbol: "arrow.triangle.2.circlepath", size: 24),
                            title: "Copy Settings from My Orca", action: onReset)
                    .disabled(busy || !store.mainOrcaHasSettings)
                SettingsRow(icon: IconTile(color: .indigo, symbol: "app.dashed", size: 24),
                            title: "Show Launcher in Finder") {
                    store.revealLauncher(barnacle)
                }
            }

            RowGroup {
                SettingsRow(icon: IconTile(color: .red, symbol: "trash", size: 24),
                            title: "Delete Barnacle\u{2026}", destructive: true, action: onDelete)
                    .disabled(busy)
            }
        }
    }
}

// MARK: - Orca missing

struct OrcaMissingView: View {
    var body: some View {
        Page {
            HeroCard(
                image: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
                    ?? NSImage(),
                title: "Orca Isn't Installed",
                subtitle: "Barnacles opens extra copies of Orca, so you need Orca first. Install it, then come back here.",
                tint: .orange
            ) {
                Link("Get Orca", destination: Orca.website)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }
}

// MARK: - New barnacle

struct NewBarnacleSheet: View {
    @EnvironmentObject private var store: BarnacleStore
    @Environment(\.dismiss) private var dismiss
    let onCreated: (Barnacle) -> Void

    @State private var name = ""
    @State private var color: BarnacleColor = .blue
    @State private var copySettings = true
    @State private var triedToCreate = false
    @FocusState private var nameFocused: Bool

    private var problem: String? { store.nameProblem(name) }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                IconTile(barnacle: preview, size: 56)
                    .shadow(color: color.color.opacity(0.4), radius: 10, y: 4)
                Text("New Barnacle")
                    .font(.system(size: 18, weight: .bold))
                Text("A separate Orca with its own projects.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            RowGroup {
                HStack(spacing: 12) {
                    Text("Name")
                        .font(.system(size: 13))
                    TextField("", text: $name, prompt: Text("Work, Side project, Client\u{2026}"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($nameFocused)
                        .onSubmit(create)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)

                HStack(spacing: 12) {
                    Text("Color")
                        .font(.system(size: 13))
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(BarnacleColor.allCases) { option in
                            Button {
                                color = option
                            } label: {
                                Circle()
                                    .fill(option.color.gradient)
                                    .frame(width: 16, height: 16)
                                    .padding(3)
                                    .overlay(
                                        Circle().strokeBorder(Color.primary.opacity(color == option ? 0.85 : 0),
                                                              lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(option.rawValue.capitalized)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use My Orca Settings")
                            .font(.system(size: 13))
                        Text(store.mainOrcaHasSettings
                             ? "Theme, agents and preferences. Projects stay separate."
                             : "No Orca settings found yet, so it starts fresh.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $copySettings)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!store.mainOrcaHasSettings)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
            }

            if triedToCreate, let problem {
                Text(problem)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create & Open", action: create)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(22)
        .frame(width: 440)
        .onAppear {
            color = BarnacleColor.allCases.first { c in !store.barnacles.contains { $0.color == c } } ?? .blue
            nameFocused = true
        }
    }

    private var preview: Barnacle {
        Barnacle(id: "preview", name: name.isEmpty ? "?" : name, color: color, folder: URL(fileURLWithPath: "/"))
    }

    private func create() {
        triedToCreate = true
        guard problem == nil else { return }
        do {
            let barnacle = try store.create(name: name, color: color,
                                            copySettings: copySettings && store.mainOrcaHasSettings)
            dismiss()
            onCreated(barnacle)
            store.open(barnacle)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}
