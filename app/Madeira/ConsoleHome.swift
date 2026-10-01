import SwiftUI

// ============================================================================
// madeira-bcd: the console-style home (Library › layout "Console", the default).
//
// One row of large tiles over the selected game's own artwork, as on a game
// console: the Wine Desktop first, then the installed Steam games (they appear
// on their own once Steam has installed them, by Madeira's downloads or by
// Valve's client in Madeira Dock) and the games you added, most recently
// played first. Tapping a tile selects it, tapping the selected tile plays it;
// Play and the ••• button (Game settings) sit under the row. A controller
// moves with left/right and starts with A. The last tile adds a game.
// ============================================================================

struct ConsoleHome: View {
    let items: [LibraryEntry]
    /// The library's sheets are closed and the Library tab is shown: controller input is ours.
    var active: Bool
    var open: (LibraryEntry) -> Void
    var play: (LibraryEntry) -> Void
    var add: () -> Void
    @ObservedObject private var controller = LibraryController.shared
    @ObservedObject private var steam = SteamOwnedLibrary.shared
    @AppStorage("madeiraConsoleFocus") private var storedFocus = ""
    @State private var focusedID: UUID?
    @State private var error: String?
    @State private var starting = false

    private var focused: LibraryEntry? {
        let id = focusedID ?? UUID(uuidString: storedFocus)
        return items.first { $0.id == id } ?? items.first
    }
    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 22) {
                        ForEach(items) { entry in tile(entry).id(entry.id) }
                        addTile
                    }.padding(.horizontal, 24).padding(.vertical, 22)
                }
                .onChange(of: focusedID) { _, id in
                    guard let id else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { reader.scrollTo(id, anchor: .center) }
                }
                .onAppear { if let id = focused?.id { reader.scrollTo(id, anchor: .center) } }
            }
            if let entry = focused { info(entry) }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { backdrop }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .environment(\.colorScheme, .dark)
        .onReceive(controller.commands) { command in
            guard active, !items.isEmpty else { return }
            let index = items.firstIndex { $0.id == focused?.id } ?? 0
            switch command {
            case "left", "up": focus(items[max(0, index - 1)].id)
            case "right", "down": focus(items[min(items.count - 1, index + 1)].id)
            case "accept": if let entry = focused { start(entry) }
            case "add": add()
            default: break
            }
        }
        .alert("Can't start yet", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: Parts

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Home").font(.title.bold())
            Spacer()
            TimelineView(.everyMinute) { context in
                Text(context.date, style: .time).font(.title3.weight(.semibold)).monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
    }

    private func tile(_ entry: LibraryEntry) -> some View {
        let isFocused = entry.id == focused?.id
        return Button {
            if isFocused { start(entry) } else { focus(entry.id) }
        } label: {
            ConsoleTileArt(entry: entry)
                .frame(width: 124, height: 186)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white, lineWidth: isFocused ? 3 : 0))
                .shadow(color: .black.opacity(isFocused ? 0.55 : 0.25), radius: isFocused ? 16 : 6, y: isFocused ? 10 : 3)
                .scaleEffect(isFocused ? 1.12 : 1)
                .opacity(isFocused ? 1 : 0.82)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { start(entry) } label: { Label("Play", systemImage: "play.fill") }
            Button { open(entry) } label: { Label("Game settings", systemImage: "slider.horizontal.3") }
        }
        .accessibilityLabel(entry.title)
        .accessibilityHint(isFocused ? "Double tap to play" : "Double tap to select")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private var addTile: some View {
        Button(action: add) {
            VStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 34, weight: .semibold))
                Text("Add game").font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 124, height: 186)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a game")
    }

    private func info(_ entry: LibraryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.title).font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            subtitle(entry).font(.subheadline).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
            HStack(spacing: 12) {
                Button { start(entry) } label: {
                    HStack(spacing: 8) { Image(systemName: "play.fill"); Text("Play") }
                        .font(.headline).padding(.horizontal, 30).frame(height: 48)
                        .background(Color.white, in: Capsule()).foregroundStyle(.black)
                }
                .buttonStyle(.plain).disabled(starting)
                Button { open(entry) } label: {
                    Image(systemName: "ellipsis").font(.headline).frame(width: 48, height: 48)
                        .background(.white.opacity(0.18), in: Circle()).foregroundStyle(.white)
                }
                .buttonStyle(.plain).accessibilityLabel("Game settings")
            }.padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .id(entry.id)
        .transition(.opacity)
    }

    @ViewBuilder private func subtitle(_ entry: LibraryEntry) -> some View {
        if entry.desktop == true {
            Text("Windows desktop · run installers, tools and any .exe")
        } else {
            let kind = entry.steamAppID != nil ? "Steam" : "Added game"
            let bits = entry.bits == 32 || entry.bits == 64 ? " · \(entry.bits)-bit" : ""
            let api = LibraryRendererBadge.compact(entry.graphicsAPI).map { " · \($0)" } ?? ""
            if let appID = entry.steamAppID, let summary = steam.playtime[appID]?.summary {
                Text(kind + bits + api + " · " + summary)
            } else if let played = entry.lastPlayed {
                Text(kind + bits + api + " · played \(played.formatted(.relative(presentation: .named)))")
            } else {
                Text(kind + bits + api)
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.10)
            if let entry = focused {
                LibraryArtwork(entry: entry, backdrop: true)
                    .blur(radius: 28).scaleEffect(1.25).opacity(0.85)
                    .id(entry.id)
                    .transition(.opacity)
            }
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55), .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: focused?.id)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func focus(_ id: UUID) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { focusedID = id }
        storedFocus = id.uuidString
    }

    private func start(_ entry: LibraryEntry) {
        guard !starting else { return }
        if let blocker = Self.blocker(entry) { error = blocker; return }
        starting = true
        focus(entry.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            LibraryModel.shared.save(entry)
            play(entry)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { starting = false }
        }
    }

    /// The checks Game details › Play makes before a Steam game starts.
    static func blocker(_ entry: LibraryEntry) -> String? {
        guard let appID = entry.steamAppID else { return nil }
        if SteamOwnedLibrary.shared.downloads[appID] != nil {
            return "This game's update has not finished. Resume it and wait for it to complete before playing."
        }
        let installed = SteamGamesModel.shared.games.first { $0.id == appID }?.installed ?? false
        if entry.startsSteamGameDirectly {
            return SteamDirectStart.blocker(installed: installed, program: entry.steamProgram)
        }
        return SteamGamesRules.blocker(installed: installed, client: MadeiraDock.clientInstalled, signedIn: SteamSignIn.isSignedIn)
    }
}

/// A tile's art: a chosen cover, Steam's artwork for a Steam game, the Wine
/// Desktop's logo, else the library's placeholder.
struct ConsoleTileArt: View {
    let entry: LibraryEntry
    var body: some View {
        if let appID = entry.steamAppID, entry.coverFile == nil {
            SteamGameArtwork(appID: appID)
        } else {
            LibraryArtwork(entry: entry)
        }
    }
}

/// The Wine Desktop's artwork: the bundled logo (WineDesktopIcon.png) on a deep blue.
struct WineDesktopArt: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.07, blue: 0.22), Color(red: 0.0, green: 0.26, blue: 0.52)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(red: 0.0, green: 0.6, blue: 1.0).opacity(0.45), .clear],
                               center: .center, startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.6)
                if let image = UIImage(named: "WineDesktopIcon") {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: min(geometry.size.width, geometry.size.height) * 0.56)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                } else {
                    Image(systemName: "desktopcomputer").font(.largeTitle).foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }
}
