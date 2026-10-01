import SwiftUI

// ============================================================================
// madeira-bcd: the Wine desktop's look.
//
// The Wine desktop (explorer /desktop=shell) draws its windows, menus, buttons
// and taskbar with the Windows system colours and window metrics in the
// prefix's HKCU (user.reg: [Control Panel\Colors], [Control Panel\Desktop\
// WindowMetrics]). win32u reads them when a session starts, so writing them
// into user.reg before the session -- while no wineserver runs and the file is
// not in use -- restyles the desktop without touching Wine itself.
//
// Never touched: "Background" and everything under [Control Panel\Desktop]
// that sets the wallpaper, so the desktop's wallpaper stays as it is.
// "Classic" removes every value written here, which brings Wine's defaults
// back. A copy of the first user.reg seen is kept as user.reg.desktop-theme-bak.
// ============================================================================

enum DesktopTheme {
    enum Style: String, CaseIterable, Identifiable {
        case modernLight, modernDark, classic
        var id: String { rawValue }
        var title: String {
            switch self {
            case .modernLight: return "Modern light"
            case .modernDark: return "Modern dark"
            case .classic: return "Classic Wine"
            }
        }
    }

    enum Accent: String, CaseIterable, Identifiable {
        case blue, teal, purple, pink, red, orange, green, graphite
        var id: String { rawValue }
        var rgb: (Int, Int, Int) {
            switch self {
            case .blue: return (0, 120, 215)
            case .teal: return (0, 153, 188)
            case .purple: return (136, 23, 152)
            case .pink: return (227, 0, 140)
            case .red: return (232, 17, 35)
            case .orange: return (247, 99, 12)
            case .green: return (16, 137, 62)
            case .graphite: return (76, 74, 72)
            }
        }
        var color: Color { Color(red: Double(rgb.0) / 255, green: Double(rgb.1) / 255, blue: Double(rgb.2) / 255) }
        var registry: String { "\(rgb.0) \(rgb.1) \(rgb.2)" }
    }

    static let styleKey = "madeiraDesktopStyle"
    static let accentKey = "madeiraDesktopAccent"
    static let touchKey = "madeiraDesktopTouchSizes"

    static var style: Style { Style(rawValue: UserDefaults.standard.string(forKey: styleKey) ?? "") ?? .modernLight }
    static var accent: Accent { Accent(rawValue: UserDefaults.standard.string(forKey: accentKey) ?? "") ?? .blue }
    static var touchSizes: Bool { UserDefaults.standard.object(forKey: touchKey) as? Bool ?? true }

    static let colorsKey = "Control Panel\\\\Colors"
    static let metricsKey = "Control Panel\\\\Desktop\\\\WindowMetrics"

    /// Every colour this theme manages; "Background" (the wallpaper colour) is deliberately absent.
    static let managedColors = [
        "ActiveBorder", "ActiveTitle", "GradientActiveTitle", "TitleText",
        "InactiveBorder", "InactiveTitle", "GradientInactiveTitle", "InactiveTitleText",
        "ButtonFace", "ButtonHilight", "ButtonLight", "ButtonShadow", "ButtonDkShadow", "ButtonText",
        "ButtonAlternateFace", "Menu", "MenuBar", "MenuText", "MenuHilight", "Hilight", "HilightText",
        "HotTrackingColor", "Window", "WindowText", "WindowFrame", "GrayText", "InfoWindow", "InfoText",
        "Scrollbar", "AppWorkspace",
    ]
    /// Window metrics in twips (negative = twips; -15 per pixel at 96 DPI).
    static let managedMetrics = ["CaptionHeight", "CaptionWidth", "SmCaptionHeight", "SmCaptionWidth",
                                 "MenuHeight", "MenuWidth", "ScrollHeight", "ScrollWidth"]

    static func colors(style: Style, accent: Accent) -> [(String, String)] {
        let a = accent.registry
        switch style {
        case .classic:
            return []
        case .modernLight:
            return [
                ("ActiveBorder", "243 243 243"), ("ActiveTitle", a), ("GradientActiveTitle", a), ("TitleText", "255 255 255"),
                ("InactiveBorder", "243 243 243"), ("InactiveTitle", "238 238 238"), ("GradientInactiveTitle", "238 238 238"),
                ("InactiveTitleText", "120 120 120"),
                ("ButtonFace", "240 240 240"), ("ButtonHilight", "255 255 255"), ("ButtonLight", "227 227 227"),
                ("ButtonShadow", "204 204 204"), ("ButtonDkShadow", "160 160 160"), ("ButtonText", "0 0 0"),
                ("ButtonAlternateFace", "240 240 240"),
                ("Menu", "249 249 249"), ("MenuBar", "249 249 249"), ("MenuText", "0 0 0"), ("MenuHilight", a),
                ("Hilight", a), ("HilightText", "255 255 255"), ("HotTrackingColor", a),
                ("Window", "255 255 255"), ("WindowText", "0 0 0"), ("WindowFrame", "160 160 160"),
                ("GrayText", "109 109 109"), ("InfoWindow", "255 255 255"), ("InfoText", "0 0 0"),
                ("Scrollbar", "232 232 232"), ("AppWorkspace", "200 200 200"),
            ]
        case .modernDark:
            return [
                ("ActiveBorder", "43 43 43"), ("ActiveTitle", a), ("GradientActiveTitle", a), ("TitleText", "255 255 255"),
                ("InactiveBorder", "43 43 43"), ("InactiveTitle", "43 43 43"), ("GradientInactiveTitle", "43 43 43"),
                ("InactiveTitleText", "160 160 160"),
                ("ButtonFace", "45 45 48"), ("ButtonHilight", "80 80 84"), ("ButtonLight", "62 62 66"),
                ("ButtonShadow", "30 30 32"), ("ButtonDkShadow", "18 18 18"), ("ButtonText", "240 240 240"),
                ("ButtonAlternateFace", "45 45 48"),
                ("Menu", "43 43 43"), ("MenuBar", "32 32 32"), ("MenuText", "240 240 240"), ("MenuHilight", a),
                ("Hilight", a), ("HilightText", "255 255 255"), ("HotTrackingColor", a),
                ("Window", "32 32 32"), ("WindowText", "240 240 240"), ("WindowFrame", "70 70 70"),
                ("GrayText", "130 130 130"), ("InfoWindow", "43 43 43"), ("InfoText", "240 240 240"),
                ("Scrollbar", "60 60 60"), ("AppWorkspace", "40 40 40"),
            ]
        }
    }

    static func metrics(style: Style, touch: Bool) -> [(String, String)] {
        guard style != .classic, touch else { return [] }
        // 26 px captions, 22 px menus, 20 px scroll bars: easier to hit with a finger.
        return [("CaptionHeight", "-390"), ("CaptionWidth", "-390"), ("SmCaptionHeight", "-330"), ("SmCaptionWidth", "-330"),
                ("MenuHeight", "-330"), ("MenuWidth", "-330"), ("ScrollHeight", "-300"), ("ScrollWidth", "-300")]
    }

    /// Writes the chosen look into user.reg. Only while no Wine session runs.
    static func applyIfNeeded() {
        guard wine_process_is_running() == 0, wineserver_is_running() == 0 else { return }
        let prefix = MadeiraDock.prefix
        madeira_seed_prefix_if_needed(prefix.path)
        let url = prefix.appendingPathComponent("user.reg")
        guard let text = try? String(contentsOf: url, encoding: .utf8), text.hasPrefix("WINE REGISTRY Version 2") else {
            LogStore.shared.log("[desktop-theme] user.reg missing or unreadable; desktop keeps its look", level: .error)
            return
        }
        let style = self.style, accent = self.accent, touch = touchSizes
        var next = set(text, section: colorsKey, values: colors(style: style, accent: accent), managed: managedColors)
        next = set(next, section: metricsKey, values: metrics(style: style, touch: touch), managed: managedMetrics)
        guard next != text else {
            LogStore.shared.log("[desktop-theme] \(style.rawValue) accent=\(accent.rawValue) touch=\(touch ? 1 : 0) (already applied)")
            return
        }
        let backup = prefix.appendingPathComponent("user.reg.desktop-theme-bak")
        if !FileManager.default.fileExists(atPath: backup.path) { try? FileManager.default.copyItem(at: url, to: backup) }
        do {
            try Data(next.utf8).write(to: url, options: .atomic)
            LogStore.shared.log("[desktop-theme] \(style.rawValue) accent=\(accent.rawValue) touch=\(touch ? 1 : 0) written to user.reg", level: .success)
        } catch {
            LogStore.shared.log("[desktop-theme] could not write user.reg: \(error.localizedDescription)", level: .error)
        }
    }

    /// Sets `values` in `[section]` and removes the `managed` names not in `values`.
    /// The section is created when it is missing and something is to be set.
    static func set(_ text: String, section: String, values: [(String, String)], managed: [String]) -> String {
        var lines = text.components(separatedBy: "\n")
        let header = "[" + section.lowercased() + "]"
        let wanted = Dictionary(values, uniquingKeysWith: { _, b in b })
        let managedLower = Set(managed.map { $0.lowercased() })
        guard let start = lines.firstIndex(where: { $0.lowercased() == header || $0.lowercased().hasPrefix(header + " ") }) else {
            guard !values.isEmpty else { return text }
            while lines.last?.isEmpty == true { lines.removeLast() }
            lines += ["", "[\(section)]"] + values.map { "\"\($0.0)\"=\"\($0.1)\"" } + [""]
            return lines.joined(separator: "\n")
        }
        var end = lines[(start + 1)...].firstIndex { $0.hasPrefix("[") } ?? lines.count
        var seen = Set<String>()
        var i = start + 1
        while i < end {
            let line = lines[i]
            if line.hasPrefix("\""), let close = line.dropFirst().firstIndex(of: "\"") {
                let name = String(line[line.index(after: line.startIndex)..<close])
                let lower = name.lowercased()
                if let key = wanted.keys.first(where: { $0.lowercased() == lower }) {
                    lines[i] = "\"\(key)\"=\"\(wanted[key]!)\""
                    seen.insert(key.lowercased())
                } else if managedLower.contains(lower) {
                    lines.remove(at: i); end -= 1; continue
                }
            }
            i += 1
        }
        // New values go after the section's last non-empty line.
        var insertAt = end
        while insertAt > start + 1 && lines[insertAt - 1].trimmingCharacters(in: .whitespaces).isEmpty { insertAt -= 1 }
        let additions = values.filter { !seen.contains($0.0.lowercased()) }.map { "\"\($0.0)\"=\"\($0.1)\"" }
        lines.insert(contentsOf: additions, at: insertAt)
        return lines.joined(separator: "\n")
    }
}

/// Settings › Wine Desktop.
struct DesktopThemeSettings: View {
    @AppStorage(DesktopTheme.styleKey) private var style = DesktopTheme.Style.modernLight.rawValue
    @AppStorage(DesktopTheme.accentKey) private var accent = DesktopTheme.Accent.blue.rawValue
    @AppStorage(DesktopTheme.touchKey) private var touch = true

    var body: some View {
        Section {
            Picker("Style", selection: $style) {
                ForEach(DesktopTheme.Style.allCases) { Text($0.title).tag($0.rawValue) }
            }
            if style != DesktopTheme.Style.classic.rawValue {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Accent colour")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(DesktopTheme.Accent.allCases) { option in
                                Button { accent = option.rawValue } label: {
                                    Circle().fill(option.color).frame(width: 30, height: 30)
                                        .overlay(Circle().stroke(Color.primary, lineWidth: accent == option.rawValue ? 3 : 0).padding(-4))
                                        .padding(4)
                                }.buttonStyle(.plain)
                                    .accessibilityLabel(option.rawValue.capitalized)
                                    .accessibilityAddTraits(accent == option.rawValue ? .isSelected : [])
                            }
                        }.padding(.vertical, 2)
                    }
                }
                Toggle("Touch-friendly title bars and menus", isOn: $touch)
            }
            DesktopThemePreview(style: DesktopTheme.Style(rawValue: style) ?? .modernLight,
                                accent: DesktopTheme.Accent(rawValue: accent) ?? .blue)
        } header: { Text("Wine Desktop") } footer: {
            Text("Applies the next time the Wine Desktop starts. The wallpaper is never changed. Classic Wine brings Wine's own colours back.")
        }
    }
}

/// A small window drawn with the chosen colours.
struct DesktopThemePreview: View {
    let style: DesktopTheme.Style
    let accent: DesktopTheme.Accent
    private func color(_ name: String, _ fallback: (Double, Double, Double)) -> Color {
        let value = DesktopTheme.colors(style: style, accent: accent).first { $0.0 == name }?.1
        let parts = value?.split(separator: " ").compactMap { Double($0) } ?? []
        let rgb = parts.count == 3 ? (parts[0], parts[1], parts[2]) : fallback
        return Color(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255)
    }
    var body: some View {
        let title = color("ActiveTitle", (0, 0, 128)), face = color("ButtonFace", (212, 208, 200))
        let window = color("Window", (255, 255, 255)), text = color("WindowText", (0, 0, 0))
        let titleText = color("TitleText", (255, 255, 255)), hilight = color("Hilight", (0, 0, 128))
        VStack(spacing: 0) {
            HStack {
                Text("Notepad").font(.caption.weight(.semibold)).foregroundStyle(titleText)
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "minus"); Image(systemName: "square"); Image(systemName: "xmark")
                }.font(.caption2).foregroundStyle(titleText)
            }.padding(.horizontal, 10).frame(height: 26).background(title)
            HStack(spacing: 14) { Text("File"); Text("Edit"); Text("View") }
                .font(.caption2).foregroundStyle(text).padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 20).background(face)
            VStack(alignment: .leading, spacing: 4) {
                Text("Hello from the Wine Desktop").font(.caption2).foregroundStyle(text)
                Text("Selected text").font(.caption2).foregroundStyle(.white).padding(.horizontal, 3).background(hilight)
            }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(window)
        }
        .clipShape(RoundedRectangle(cornerRadius: style == .classic ? 0 : 8))
        .overlay(RoundedRectangle(cornerRadius: style == .classic ? 0 : 8).stroke(Color.secondary.opacity(0.4)))
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}
