import Combine
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BarnacleStore
    @State private var pendingDelete: Barnacle?
    @State private var pendingReset: Barnacle?

    private let ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if !store.orcaInstalled {
                OrcaMissingView()
            } else if store.barnacles.isEmpty {
                EmptyStateView()
            } else {
                List {
                    Section {
                        ForEach(store.barnacles) { barnacle in
                            BarnacleRow(barnacle: barnacle,
                                        onReset: { pendingReset = barnacle },
                                        onDelete: { pendingDelete = barnacle })
                        }
                    } footer: {
                        Text("Each barnacle is a separate Orca with its own projects. You can also open one from Spotlight: type \u{201C}Orca\u{201D} and its name.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 460, minHeight: 340)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.showingNewSheet = true
                } label: {
                    Label("New Barnacle", systemImage: "plus")
                }
                .help("Create a new barnacle")
                .disabled(!store.orcaInstalled)
            }
        }
        .sheet(isPresented: $store.showingNewSheet) {
            NewBarnacleSheet()
        }
        .alert(item: $pendingDelete) { barnacle in
            Alert(
                title: Text("Delete \u{201C}\(barnacle.name)\u{201D}?"),
                message: Text((store.isRunning(barnacle) ? "It will be closed first. " : "")
                    + "Its project list, sessions and settings go to the Trash. Your code and repositories aren't touched."),
                primaryButton: .destructive(Text("Move to Trash")) { store.delete(barnacle) },
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
}

// MARK: - Rows

struct BarnacleRow: View {
    @EnvironmentObject private var store: BarnacleStore
    let barnacle: Barnacle
    let onReset: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let running = store.isRunning(barnacle)
        let busy = store.isBusy(barnacle)

        HStack(spacing: 12) {
            BarnacleBadge(barnacle: barnacle, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(barnacle.name)
                    .font(.headline)
                HStack(spacing: 5) {
                    Circle()
                        .fill(running ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text(running ? "Running" : "Not running")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if busy {
                ProgressView().controlSize(.small)
            }

            Button(running ? "Show" : "Open") { store.open(barnacle) }
                .buttonStyle(.borderedProminent)
                .tint(running ? .secondary : .accentColor)
                .disabled(busy)

            Menu {
                if running {
                    Button("Quit") { store.quit(barnacle) }
                }
                Button("Copy Settings from My Orca…", action: onReset)
                    .disabled(!store.mainOrcaHasSettings)
                Button("Show Launcher in Finder") { store.revealLauncher(barnacle) }
                Divider()
                Button("Delete…", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(busy)
            .help("More")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if !busy { store.open(barnacle) } }
    }
}

struct BarnacleBadge: View {
    let barnacle: Barnacle
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(barnacle.color.color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(String(barnacle.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - Empty states

struct EmptyStateView: View {
    @EnvironmentObject private var store: BarnacleStore

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Run more than one Orca")
                .font(.title2.weight(.semibold))
            Text("Each barnacle is its own Orca window, with its own projects and sessions. Open as many as you like, side by side.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)
            Button("Create Your First Barnacle") { store.showingNewSheet = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OrcaMissingView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Orca isn't installed")
                .font(.title2.weight(.semibold))
            Text("Barnacles opens extra copies of Orca, so you need Orca first. Install it, then come back here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)
            Link("Get Orca", destination: Orca.website)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - New barnacle

struct NewBarnacleSheet: View {
    @EnvironmentObject private var store: BarnacleStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var color: BarnacleColor = .blue
    @State private var copySettings = true
    @State private var triedToCreate = false
    @FocusState private var nameFocused: Bool

    private var problem: String? { store.nameProblem(name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                BarnacleBadge(barnacle: preview, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Barnacle")
                        .font(.title3.weight(.semibold))
                    Text("A separate Orca with its own projects.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.subheadline.weight(.medium))
                TextField("", text: $name, prompt: Text("Work, Side project, Client…"))
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(create)
                if triedToCreate, let problem {
                    Text(problem)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    ForEach(BarnacleColor.allCases) { option in
                        Button {
                            color = option
                        } label: {
                            Circle()
                                .fill(option.color.gradient)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(color == option ? 0.8 : 0), lineWidth: 2)
                                        .padding(-4)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(option.rawValue.capitalized)
                    }
                }
                .padding(.leading, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Use the same settings as my Orca", isOn: $copySettings)
                    .disabled(!store.mainOrcaHasSettings)
                Text(store.mainOrcaHasSettings
                     ? "Theme, agents and preferences. Projects stay separate."
                     : "No Orca settings found yet, so this barnacle starts fresh.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create & Open", action: create)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 400)
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
            store.open(barnacle)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}
