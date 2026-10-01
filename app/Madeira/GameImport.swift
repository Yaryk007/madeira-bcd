import SwiftUI
import UniformTypeIdentifiers

// ============================================================================
// madeira-bcd: adding a game with the + button -- a game folder or an .exe
// picked in the Files app, from anywhere.
//
// Wine can only open files inside its drive_c, so a pick from outside it is
// copied to drive_c/Games/<name> first (a folder with everything in it; an
// .exe alone when only the file was picked, since iOS grants access to that
// one file). A pick already inside drive_c is used where it is. A folder's
// program is its only .exe, or the one chosen from the list (largest first,
// installers and crash reporters last).
// ============================================================================

enum GameImport {
    enum Kind { case folder, executable }

    static var exeType: UTType { UTType(filenameExtension: "exe", conformingTo: .data) ?? .data }

    enum Outcome {
        case added(LibraryEntry)
        case choose(folder: URL, title: String, programs: [URL])
    }

    /// Programs that are not the game itself.
    static func isNoise(_ name: String) -> Bool {
        let lower = name.lowercased()
        return ["unins", "setup", "install", "redist", "vcredist", "dxsetup", "dotnet", "crash", "report",
                "uninstall", "updater", "ue4prereq", "physx"].contains { lower.contains($0) }
    }

    /// The folder's programs, at most six folders deep: games first (largest first), then the rest.
    static func programs(in folder: URL) -> [URL] {
        let fm = FileManager.default
        var found: [(URL, Int)] = []
        func walk(_ url: URL, _ depth: Int) {
            guard depth <= 6, found.count < 400,
                  let names = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey],
                                                         options: .skipsHiddenFiles) else { return }
            for child in names {
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
                if values?.isSymbolicLink == true { continue }
                if values?.isDirectory == true { walk(child, depth + 1) }
                else if child.pathExtension.lowercased() == "exe" { found.append((child, values?.fileSize ?? 0)) }
            }
        }
        walk(folder, 0)
        return found.sorted {
            let (a, b) = (isNoise($0.0.lastPathComponent), isNoise($1.0.lastPathComponent))
            if a != b { return !a }
            return $0.1 > $1.1
        }.map { $0.0 }
    }

    /// An unused folder under drive_c/Games for `name`.
    static func destination(for name: String) throws -> URL {
        let games = LibraryModel.drive.appendingPathComponent("Games", isDirectory: true)
        try FileManager.default.createDirectory(at: games, withIntermediateDirectories: true)
        let clean = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = clean.isEmpty ? "Game" : clean
        var candidate = games.appendingPathComponent(base, isDirectory: true)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = games.appendingPathComponent("\(base) \(n)", isDirectory: true); n += 1
        }
        return candidate
    }

    static func insideDrive(_ url: URL) -> Bool {
        url.resolvingSymlinksInPath().path.hasPrefix(LibraryModel.drive.resolvingSymlinksInPath().path + "/")
    }

    /// Runs off the main thread. `status` reports what is happening.
    static func run(_ picked: URL, kind: Kind, status: @escaping (String) -> Void) throws -> Outcome {
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        var target = picked
        var copiedAlone = false
        if !insideDrive(picked) {
            let name = kind == .folder ? picked.lastPathComponent : picked.deletingPathExtension().lastPathComponent
            let folder = try destination(for: name)
            status("Copying \(picked.lastPathComponent) into Madeira…")
            var coordinatorError: NSError?
            var copyError: Error?
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: picked, options: [], error: &coordinatorError) { source in
                do {
                    if kind == .folder {
                        try fm.copyItem(at: source, to: folder)
                    } else {
                        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                        try fm.copyItem(at: source, to: folder.appendingPathComponent(source.lastPathComponent))
                    }
                } catch { copyError = error }
            }
            if let error = copyError ?? coordinatorError {
                try? fm.removeItem(at: folder)
                throw LibraryError.message("The game could not be copied: \(error.localizedDescription)")
            }
            target = kind == .folder ? folder : folder.appendingPathComponent(picked.lastPathComponent)
            copiedAlone = kind == .executable
            LogStore.shared.log("[game-import] copied \(kind == .folder ? "folder" : "exe") into drive_c/Games/\(folder.lastPathComponent)")
        }
        status("Looking for the game's program…")
        if kind == .executable {
            guard target.pathExtension.lowercased() == "exe" else { throw LibraryError.message("Choose a Windows program (.exe).") }
            var entry = try LibraryModel.inspect(target)
            let parent = target.deletingLastPathComponent()
            let generic = ["games", "drive_c", "bin", "bin64", "binaries", "win64", "x64"]
            entry.title = copiedAlone || generic.contains(parent.lastPathComponent.lowercased())
                ? target.deletingPathExtension().lastPathComponent : parent.lastPathComponent
            return .added(entry)
        }
        let found = programs(in: target)
        guard !found.isEmpty else { throw LibraryError.message("There is no Windows program (.exe) in \(target.lastPathComponent).") }
        let games = found.filter { !isNoise($0.lastPathComponent) }
        if games.count == 1 {
            var entry = try LibraryModel.inspect(games[0])
            entry.title = target.lastPathComponent
            return .added(entry)
        }
        return .choose(folder: target, title: target.lastPathComponent, programs: found)
    }
}

/// The sheet the + button's picks open: copies when needed, then adds the game
/// or lists the folder's programs to choose from.
struct GameImportSheet: View {
    let picked: URL
    let kind: GameImport.Kind
    var done: (LibraryEntry?) -> Void
    @State private var status = "Preparing…"
    @State private var error: String?
    @State private var choice: (folder: URL, title: String, programs: [URL])?

    var body: some View {
        NavigationStack {
            Group {
                if let error {
                    ContentUnavailableView("Couldn't add the game", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if let choice {
                    List {
                        Section {
                            ForEach(Array(choice.programs.enumerated()), id: \.element.path) { index, program in
                                Button { pick(program, title: choice.title) } label: {
                                    HStack {
                                        Image(systemName: index == 0 ? "star.fill" : "app.dashed")
                                            .foregroundStyle(index == 0 ? Color.yellow : Color.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(program.lastPathComponent).foregroundStyle(.primary)
                                            Text(relative(program, to: choice.folder)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                }
                            }
                        } header: { Text("Which program starts \(choice.title)?") } footer: {
                            Text("The starred one is the most likely: the largest program that is not an installer.")
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView().controlSize(.large)
                        Text(status).font(.headline).multilineTextAlignment(.center)
                        Text("Large games take a while to copy. Keep Madeira open.").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(32)
                }
            }
            .navigationTitle("Add game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // A copy cannot be stopped half-way: the sheet stays until it ends.
                if error != nil || choice != nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } }
                }
            }
        }
        .interactiveDismissDisabled(error == nil && choice == nil)
        .task {
            let url = self.picked, pickKind = self.kind
            let report: (String) -> Void = { text in DispatchQueue.main.async { status = text } }
            let result: Result<GameImport.Outcome, Error> = await Task.detached(priority: .userInitiated) {
                Result { try GameImport.run(url, kind: pickKind, status: report) }
            }.value
            switch result {
            case .success(.added(let entry)): done(entry)
            case .success(.choose(let folder, let title, let programs)): choice = (folder, title, programs)
            case .failure(let failure): error = failure.localizedDescription
            }
        }
    }

    private func relative(_ url: URL, to folder: URL) -> String {
        let path = url.path, base = folder.path + "/"
        return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : url.lastPathComponent
    }

    private func pick(_ program: URL, title: String) {
        do {
            var entry = try LibraryModel.inspect(program)
            entry.title = title
            done(entry)
        } catch { self.error = error.localizedDescription }
    }
}

/// The picked item, for `.sheet(item:)`.
struct PickedGame: Identifiable {
    let id = UUID()
    let url: URL
    let kind: GameImport.Kind
}
