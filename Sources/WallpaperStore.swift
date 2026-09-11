import SwiftUI
import AppKit
import ImageIO

struct Favorite: Codable, Identifiable, Hashable {
    let slug: String
    let title: String
    var remoteURL: String? = nil
    var id: String { slug }
}

@MainActor
final class WallpaperStore: ObservableObject {
    @Published var preview: NSImage?
    @Published var wallpaperTitle: String = ""
    @Published var isLoading = false
    @Published var poolCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var themeCounts: [String: Int] = [:]
    @Published var isPreparing = false
    @Published var selectedThemeID: String = UserDefaults.standard.string(forKey: "villblomst.theme") ?? "alle"
    @Published var sourceID: String = UserDefaults.standard.string(forKey: "villblomst.source") ?? WallpaperSource.bing.rawValue
    @Published var separatePerScreen: Bool = UserDefaults.standard.bool(forKey: "villblomst.perScreen")
    @Published var screenAssignments: [String: Favorite] = [:]
    @Published var favorites: [Favorite] = []
    @Published var favoriteThumbnails: [String: NSImage] = [:]
    private(set) var currentSlug: String?
    private var currentRemoteURL: URL?

    private(set) var statusState: StoreStatus = .idle
    var status: String { Localization.shared.text(for: statusState) }

    var source: WallpaperSource { WallpaperSource(rawValue: sourceID) ?? .bing }
    var sourceName: String { Localization.shared.t("source.\(source.rawValue)") }
    var sourceAttribution: String {
        source == .bing ? "bingwallpaper.anerg.com" : "Windows Spotlight (Microsoft)"
    }

    var screenCount: Int { NSScreen.screens.count }
    private var usesSeparatePerScreen: Bool { separatePerScreen && screenCount > 1 }

    func screenLabel(_ index: Int) -> String {
        if index == 0 {
            return String(format: Localization.shared.t("screen.labelPrimary"), index + 1)
        }
        return String(format: Localization.shared.t("screen.label"), index + 1)
    }

    func assignedScreenNumbers(for favorite: Favorite) -> [Int] {
        screenAssignments
            .filter { $0.value.slug == favorite.slug }
            .compactMap { Int($0.key) }
            .sorted()
    }

    func togglePerScreen() {
        separatePerScreen.toggle()
        UserDefaults.standard.set(separatePerScreen, forKey: "villblomst.perScreen")
    }

    var isCurrentFavorite: Bool {
        guard let slug = currentSlug else { return false }
        return favorites.contains { $0.slug == slug }
    }

    let themes = WallpaperTheme.all

    private var currentTheme: WallpaperTheme {
        themes.first { $0.id == selectedThemeID } ?? themes[0]
    }

    var selectedThemeName: String { Localization.shared.themeName(currentTheme.id) }

    private static let themeKey = "villblomst.theme"

    private var pool: [Wallpaper] = []
    private var recent: [String] = []

    private let session = Scraper.makeSession()
    private let folder: URL
    private let imageFolder: URL
    private let poolFile: URL
    private let stateFile: URL
    private let favoritesFile: URL
    private let screensFile: URL

    private struct State: Codable {
        var recent: [String]
        var title: String
        var imageName: String?
        var currentSlug: String?
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Villblomst", isDirectory: true)
        folder = support
        imageFolder = support.appendingPathComponent("Wallpapers", isDirectory: true)
        poolFile = support.appendingPathComponent("pool.json")
        stateFile = support.appendingPathComponent("state.json")
        favoritesFile = support.appendingPathComponent("favorites.json")
        screensFile = support.appendingPathComponent("screens.json")
        try? FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
        loadFavorites()
        loadScreenAssignments()
        restoreState()
    }

    private func restoreState() {
        guard let data = try? Data(contentsOf: stateFile),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return }
        recent = state.recent
        wallpaperTitle = state.title
        currentSlug = state.currentSlug
        if let name = state.imageName {
            let url = imageFolder.appendingPathComponent(name)
            preview = NSImage(contentsOf: url)
        }
        loadCachedPool()
    }

    private func loadFavorites() {
        guard let data = try? Data(contentsOf: favoritesFile),
              let saved = try? JSONDecoder().decode([Favorite].self, from: data) else { return }
        favorites = saved
    }

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            try? data.write(to: favoritesFile, options: .atomic)
        }
    }

    private func loadScreenAssignments() {
        guard let data = try? Data(contentsOf: screensFile),
              let saved = try? JSONDecoder().decode([String: Favorite].self, from: data) else { return }
        screenAssignments = saved
    }

    private func persistScreenAssignments() {
        if let data = try? JSONEncoder().encode(screenAssignments) {
            try? data.write(to: screensFile, options: .atomic)
        }
    }

    func toggleFavorite() {
        guard let slug = currentSlug, !wallpaperTitle.isEmpty else { return }
        if let index = favorites.firstIndex(where: { $0.slug == slug }) {
            favorites.remove(at: index)
            favoriteThumbnails[slug] = nil
            persistFavorites()
            statusState = .favoriteRemoved
        } else {
            favorites.insert(Favorite(slug: slug, title: wallpaperTitle, remoteURL: currentRemoteURL?.absoluteString), at: 0)
            persistFavorites()
            loadFavoriteThumbnails()
            statusState = .favoriteAdded
        }
    }

    func removeFavorite(_ favorite: Favorite) {
        favorites.removeAll { $0.slug == favorite.slug }
        favoriteThumbnails[favorite.slug] = nil
        persistFavorites()
        statusState = .favoriteRemoved
    }

    func applyFavorite(_ favorite: Favorite) async {
        guard !isLoading else { return }
        do {
            let file = try await ensureLocalFile(for: favorite)
            try setAsDesktop(file)
            preview = NSImage(contentsOf: file)
            wallpaperTitle = favorite.title
            currentSlug = favorite.slug
            currentRemoteURL = favorite.remoteURL.flatMap(URL.init(string:))
            persistState(imageName: file.lastPathComponent)
            statusState = .favoriteApplied
        } catch {
            isLoading = false
            statusState = .error(error.localizedDescription)
        }
    }

    func assign(_ favorite: Favorite, toScreen index: Int) async {
        let screens = NSScreen.screens
        guard screens.indices.contains(index) else { return }
        do {
            isLoading = true
            defer { isLoading = false }
            let file = try await ensureLocalFile(for: favorite)
            try setAsDesktop(file, on: screens[index])
            screenAssignments[String(index)] = favorite
            persistScreenAssignments()
            if currentSlug == nil {
                preview = NSImage(contentsOf: file)
                wallpaperTitle = favorite.title
                currentSlug = favorite.slug
                currentRemoteURL = favorite.remoteURL.flatMap(URL.init(string:))
                persistState(imageName: file.lastPathComponent)
            }
            statusState = .screenAssigned(index: index)
        } catch {
            statusState = .error(error.localizedDescription)
        }
    }

    private func ensureLocalFile(for favorite: Favorite) async throws -> URL {
        let file = imageFolder.appendingPathComponent("\(favorite.slug).jpg")
        if FileManager.default.fileExists(atPath: file.path) { return file }
        isLoading = true
        statusState = .fetching(favorite.title)
        defer { isLoading = false }
        let remote: URL
        if let string = favorite.remoteURL, let url = URL(string: string) {
            remote = url
        } else {
            remote = try await Scraper.detail4KURL(slug: favorite.slug, session: session)
        }
        try await Scraper.download(remote, to: file, session: session)
        return file
    }

    func loadFavoriteThumbnails() {
        for favorite in favorites where favoriteThumbnails[favorite.slug] == nil {
            let url = imageFolder.appendingPathComponent("\(favorite.slug).jpg")
            if let image = Self.thumbnail(for: url) {
                favoriteThumbnails[favorite.slug] = image
            }
        }
    }

    private static func thumbnail(for url: URL, maxPixel: CGFloat = 400) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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
        statusState = .theme(id: theme.id, count: poolCount)
    }

    func selectSource(_ source: WallpaperSource) {
        sourceID = source.rawValue
        UserDefaults.standard.set(source.rawValue, forKey: "villblomst.source")
        if source == .bing {
            statusState = .theme(id: currentTheme.id, count: poolCount)
        } else {
            statusState = .idle
        }
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
        statusState = .searching
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
        statusState = .theme(id: currentTheme.id, count: poolCount)
    }

    func next() async {
        if source == .spotlight {
            await nextSpotlight()
            return
        }
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
        let count = usesSeparatePerScreen ? NSScreen.screens.count : 1
        let picks = pickMany(from: source, count: count)
        guard !picks.isEmpty else {
            statusState = .noImages
            return
        }

        let screens = NSScreen.screens
        do {
            var primaryFile: URL?
            for (index, choice) in picks.enumerated() where screens.indices.contains(index) {
                if count > 1 {
                    statusState = .screenProgress(index + 1, count)
                } else {
                    statusState = .fetching(choice.title)
                }
                let remote = try await Scraper.detail4KURL(slug: choice.slug, session: session)
                let file = imageFolder.appendingPathComponent("\(choice.slug).jpg")
                if count == 1 { statusState = .downloading }
                try await Scraper.download(remote, to: file, session: session)
                try setAsDesktop(file, on: screens[index])
                if index == 0 {
                    primaryFile = file
                    preview = NSImage(contentsOf: file)
                    wallpaperTitle = choice.title
                    currentSlug = choice.slug
                    currentRemoteURL = remote
                }
                recent.append(choice.slug)
            }
            if recent.count > 12 { recent.removeFirst(recent.count - 12) }
            if let primaryFile {
                persistState(imageName: primaryFile.lastPathComponent)
            }
            statusState = picks.count > 1 ? .perScreenApplied(picks.count) : .applied
        } catch {
            statusState = .error(error.localizedDescription)
        }
    }

    private func pickMany(from source: [Wallpaper], count: Int) -> [Wallpaper] {
        guard !source.isEmpty else { return [] }
        var available = source.filter { !recent.contains($0.slug) }
        if available.isEmpty {
            recent.removeAll()
            available = source
        }
        var picks = available.shuffled()
        if picks.count < count {
            picks.append(contentsOf: source.shuffled())
        }
        return Array(picks.prefix(count))
    }

    private func nextSpotlight() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        statusState = .searching

        let info = SpotlightAPI.localeInfo()
        let needed = usesSeparatePerScreen ? NSScreen.screens.count : 1
        var collected: [SpotlightImage] = []
        var seen = Set<String>()
        var themed: [SpotlightImage] = []

        do {
            for _ in 0..<8 {
                let batch = try await SpotlightAPI.fetchOnce(locale: info.locale, country: info.country, session: session)
                for image in batch where seen.insert(image.id).inserted {
                    collected.append(image)
                }
                themed = collected.filter { !recent.contains($0.id) && currentTheme.matches($0.searchText) }
                if themed.count >= max(needed, 4) { break }
            }
        } catch {
            statusState = .error(error.localizedDescription)
            return
        }

        let candidates = themed.isEmpty ? collected : themed
        var available = candidates.filter { !recent.contains($0.id) }
        if available.isEmpty { available = candidates }
        guard !available.isEmpty else {
            statusState = .noImages
            return
        }

        var picks = available.shuffled()
        if picks.count < needed {
            picks.append(contentsOf: candidates.shuffled())
        }
        picks = Array(picks.prefix(needed))

        let screens = NSScreen.screens
        do {
            var primaryFile: URL?
            for (index, choice) in picks.enumerated() where screens.indices.contains(index) {
                if needed > 1 {
                    statusState = .screenProgress(index + 1, needed)
                } else {
                    statusState = .fetching(choice.displayTitle)
                }
                let file = imageFolder.appendingPathComponent("\(choice.id).jpg")
                if needed == 1 { statusState = .downloading }
                try await Scraper.download(choice.url, to: file, session: session)
                try setAsDesktop(file, on: screens[index])
                if index == 0 {
                    primaryFile = file
                    preview = NSImage(contentsOf: file)
                    wallpaperTitle = choice.displayTitle
                    currentSlug = choice.id
                    currentRemoteURL = choice.url
                }
                recent.append(choice.id)
            }
            if recent.count > 12 { recent.removeFirst(recent.count - 12) }
            if let primaryFile {
                persistState(imageName: primaryFile.lastPathComponent)
            }
            statusState = picks.count > 1 ? .perScreenApplied(picks.count) : .applied
        } catch {
            statusState = .error(error.localizedDescription)
        }
    }

    private func setAsDesktop(_ url: URL, on screen: NSScreen) throws {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true
        ]
        try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
    }

    private func setAsDesktop(_ url: URL) throws {
        for screen in NSScreen.screens {
            try setAsDesktop(url, on: screen)
        }
    }

    private func persistState(imageName: String?) {
        let state = State(recent: recent, title: wallpaperTitle, imageName: imageName, currentSlug: currentSlug)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateFile, options: .atomic)
        }
    }
}

enum StoreStatus: Equatable {
    case idle
    case searching
    case theme(id: String, count: Int)
    case fetching(String)
    case downloading
    case applied
    case favoriteAdded
    case favoriteRemoved
    case favoriteApplied
    case screenProgress(Int, Int)
    case perScreenApplied(Int)
    case screenAssigned(index: Int)
    case noImages
    case error(String)
}
