import SwiftUI
import AppKit
import ImageIO

struct Favorite: Codable, Identifiable, Hashable {
    let slug: String
    let title: String
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
    @Published var favorites: [Favorite] = []
    @Published var favoriteThumbnails: [String: NSImage] = [:]
    private(set) var currentSlug: String?

    private(set) var statusState: StoreStatus = .idle
    var status: String { Localization.shared.text(for: statusState) }

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
        try? FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
        loadFavorites()
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

    func toggleFavorite() {
        guard let slug = currentSlug, !wallpaperTitle.isEmpty else { return }
        if let index = favorites.firstIndex(where: { $0.slug == slug }) {
            favorites.remove(at: index)
            favoriteThumbnails[slug] = nil
            persistFavorites()
            statusState = .favoriteRemoved
        } else {
            favorites.insert(Favorite(slug: slug, title: wallpaperTitle), at: 0)
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
        let file = imageFolder.appendingPathComponent("\(favorite.slug).jpg")
        do {
            if !FileManager.default.fileExists(atPath: file.path) {
                isLoading = true
                statusState = .fetching(favorite.title)
                let remote = try await Scraper.detail4KURL(slug: favorite.slug, session: session)
                try await Scraper.download(remote, to: file, session: session)
                isLoading = false
            }
            try setAsDesktop(file)
            preview = NSImage(contentsOf: file)
            wallpaperTitle = favorite.title
            currentSlug = favorite.slug
            persistState(imageName: file.lastPathComponent)
            statusState = .favoriteApplied
        } catch {
            isLoading = false
            statusState = .error(error.localizedDescription)
        }
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
            statusState = .noImages
            return
        }

        statusState = .fetching(choice.title)
        do {
            let remote = try await Scraper.detail4KURL(slug: choice.slug, session: session)
            let file = imageFolder.appendingPathComponent("\(choice.slug).jpg")
            statusState = .downloading
            try await Scraper.download(remote, to: file, session: session)
            try setAsDesktop(file)
            preview = NSImage(contentsOf: file)
            wallpaperTitle = choice.title
            currentSlug = choice.slug

            recent.append(choice.slug)
            if recent.count > 12 { recent.removeFirst(recent.count - 12) }
            persistState(imageName: file.lastPathComponent)
            statusState = .applied
        } catch {
            statusState = .error(error.localizedDescription)
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
    case noImages
    case error(String)
}
