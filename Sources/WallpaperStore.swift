import SwiftUI
import AppKit

@MainActor
final class WallpaperStore: ObservableObject {
    @Published var preview: NSImage?
    @Published var wallpaperTitle: String = ""
    @Published var status: String = "Trykk på knappen for en ny bakgrunn"
    @Published var isLoading = false
    @Published var poolCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var themeCounts: [String: Int] = [:]
    @Published var isPreparing = false
    @Published var selectedThemeID: String = UserDefaults.standard.string(forKey: "villblomst.theme") ?? "alle"

    let themes = WallpaperTheme.all

    private var currentTheme: WallpaperTheme {
        themes.first { $0.id == selectedThemeID } ?? themes[0]
    }

    var selectedThemeName: String { currentTheme.name }

    private static let themeKey = "villblomst.theme"

    private var pool: [Wallpaper] = []
    private var recent: [String] = []

    private let session = Scraper.makeSession()
    private let folder: URL
    private let imageFolder: URL
    private let poolFile: URL
    private let stateFile: URL

    private struct State: Codable {
        var recent: [String]
        var title: String
        var imageName: String?
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Villblomst", isDirectory: true)
        folder = support
        imageFolder = support.appendingPathComponent("Wallpapers", isDirectory: true)
        poolFile = support.appendingPathComponent("pool.json")
        stateFile = support.appendingPathComponent("state.json")
        try? FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
        restoreState()
    }

    private func restoreState() {
        guard let data = try? Data(contentsOf: stateFile),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return }
        recent = state.recent
        wallpaperTitle = state.title
        if let name = state.imageName {
            let url = imageFolder.appendingPathComponent(name)
            preview = NSImage(contentsOf: url)
        }
        loadCachedPool()
    }

    private func loadCachedPool() {
        guard let data = try? Data(contentsOf: poolFile),
              let cached = try? JSONDecoder().decode(CachedPool.self, from: data),
              cached.version == Self.cacheVersion else { return }
        let age = Date().timeIntervalSince(cached.date)
        guard age < 60 * 60 * 24 * 7 else { return }
        pool = cached.items
        computeCounts()
    }

    private func computeCounts() {
        var counts: [String: Int] = [:]
        for theme in themes {
            counts[theme.id] = pool.reduce(0) { $0 + (theme.matches($1.title) ? 1 : 0) }
        }
        themeCounts = counts
        totalCount = pool.count
        poolCount = counts[selectedThemeID] ?? pool.count
    }

    func select(_ theme: WallpaperTheme) {
        selectedThemeID = theme.id
        UserDefaults.standard.set(theme.id, forKey: Self.themeKey)
        poolCount = themeCounts[theme.id] ?? pool.count
        status = "Tema: \(theme.name) – \(poolCount) bilder"
    }

    private static let cacheVersion = 2

    private struct CachedPool: Codable {
        var version: Int = 2
        var date: Date
        var items: [Wallpaper]
    }

    func preparePool(force: Bool = false) async {
        if !force, !pool.isEmpty {
            computeCounts()
            return
        }
        if !force, let data = try? Data(contentsOf: poolFile),
           let cached = try? JSONDecoder().decode(CachedPool.self, from: data),
           cached.version == Self.cacheVersion,
           Date().timeIntervalSince(cached.date) < 60 * 60 * 24 * 7 {
            pool = cached.items
            computeCounts()
            return
        }
        guard !isPreparing else { return }
        isPreparing = true
        status = "Søker gjennom Bing-arkivet …"
        let months = Scraper.monthStrings(back: 60)
        let fetched = await Scraper.pool(months: months, session: session)
        if fetched.isEmpty {
            pool = Scraper.fallback
        } else {
            pool = fetched
            if let data = try? JSONEncoder().encode(CachedPool(version: Self.cacheVersion, date: Date(), items: fetched)) {
                try? data.write(to: poolFile, options: .atomic)
            }
        }
        computeCounts()
        isPreparing = false
        status = "Tema: \(currentTheme.name) – \(poolCount) bilder"
    }

    func next() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if pool.isEmpty {
            await preparePool()
        }
        if pool.isEmpty {
            pool = Scraper.fallback
            computeCounts()
        }

        let themed = pool.filter { currentTheme.matches($0.title) }
        let source = themed.isEmpty ? pool : themed
        var available = source.filter { !recent.contains($0.slug) }
        if available.isEmpty {
            recent.removeAll()
            available = source
        }
        guard let choice = available.randomElement() else {
            status = "Fant ingen bilder akkurat nå"
            return
        }

        status = "Henter «\(choice.title)» i 4K …"
        do {
            let remote = try await Scraper.detail4KURL(slug: choice.slug, session: session)
            let file = imageFolder.appendingPathComponent("\(choice.slug).jpg")
            status = "Laster ned 4K-bildet …"
            try await Scraper.download(remote, to: file, session: session)
            try setAsDesktop(file)
            preview = NSImage(contentsOf: file)
            wallpaperTitle = choice.title

            recent.append(choice.slug)
            if recent.count > 12 { recent.removeFirst(recent.count - 12) }
            persistState(imageName: file.lastPathComponent)
            status = "Bakgrunnen er satt"
        } catch {
            status = "Noe gikk galt: \(error.localizedDescription)"
        }
    }

    private func setAsDesktop(_ url: URL) throws {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true
        ]
        for screen in screens {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        }
    }

    private func persistState(imageName: String?) {
        let state = State(recent: recent, title: wallpaperTitle, imageName: imageName)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateFile, options: .atomic)
        }
    }
}
