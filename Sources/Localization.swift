import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case norwegian
    case english

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .norwegian: return "Norsk"
        case .english: return "English"
        }
    }
}

final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.key) }
    }

    private static let key = "villblomst.language"

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: raw) ?? .system
    }

    /// Resolved two-letter language code: "nb" or "en".
    var code: String {
        switch language {
        case .norwegian: return "nb"
        case .english: return "en"
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            if preferred.hasPrefix("nb") || preferred.hasPrefix("nn") || preferred.hasPrefix("no") {
                return "nb"
            }
            return "en"
        }
    }

    var isNorwegian: Bool { code == "nb" }

    func t(_ key: String) -> String {
        let table = isNorwegian ? Self.norwegian : Self.english
        return table[key] ?? Self.english[key] ?? key
    }

    func themeName(_ id: String) -> String {
        t("theme.\(id)")
    }

    func text(for status: StoreStatus) -> String {
        switch status {
        case .idle:
            return t("status.idle")
        case .searching:
            return t("status.searching")
        case .theme(let id, let count):
            return String(format: t("status.theme"), themeName(id), count)
        case .fetching(let title):
            return String(format: t("status.fetching"), title)
        case .downloading:
            return t("status.downloading")
        case .applied:
            return t("status.applied")
        case .favoriteAdded:
            return t("status.favoriteAdded")
        case .favoriteRemoved:
            return t("status.favoriteRemoved")
        case .favoriteApplied:
            return t("status.favoriteApplied")
        case .screenProgress(let index, let total):
            return String(format: t("status.screenProgress"), index, total)
        case .perScreenApplied(let count):
            return String(format: t("status.perScreenApplied"), count)
        case .screenAssigned(let index):
            return String(format: t("status.screenAssigned"), index + 1)
        case .noImages:
            return t("status.noImages")
        case .error(let message):
            return String(format: t("status.error"), message)
        }
    }

    private static let norwegian: [String: String] = [
        "tagline": "Tilfeldige 4K-bakgrunner",
        "settings.source.title": "Bildekilde",
        "settings.source.subtitle": "Velg hvor bakgrunnene hentes fra",
        "settings.title": "Bakgrunnstema",
        "settings.subtitle": "Velg hvilke typer bilder som skal hentes",
        "settings.imagesCount": "%d bilder",
        "settings.matchSummary": "%d av %d bilder passer til «%@»",
        "settings.spotlightNote": "Spotlight-bilder filtreres også etter valgt tema.",
        "settings.perscreen.title": "Bakgrunn per skjerm",
        "settings.perscreen.subtitle": "La hver skjerm få sitt eget tilfeldige bilde",
        "settings.perscreen.toggle": "Egen bakgrunn per skjerm",
        "settings.help": "Innstillinger",
        "settings.language.title": "Språk",
        "settings.language.subtitle": "Velg språk for grensesnittet",
        "button.new": "Ny bakgrunn",
        "button.loading": "Henter …",
        "preview.empty": "Ingen bakgrunn ennå",
        "preview.ready": "Klar til å hente en bakgrunn",
        "footer.count": "%d av %d bilder",
        "status.idle": "Trykk på knappen for en ny bakgrunn",
        "status.searching": "Søker etter bakgrunner …",
        "status.theme": "Tema: %@ – %d bilder",
        "status.fetching": "Henter «%@» i 4K …",
        "status.downloading": "Laster ned 4K-bildet …",
        "status.applied": "Bakgrunnen er satt",
        "status.favoriteAdded": "Lagt til i favoritter",
        "status.favoriteRemoved": "Fjernet fra favoritter",
        "status.favoriteApplied": "Favoritten er satt som bakgrunn",
        "status.screenProgress": "Henter bilde %d av %d …",
        "status.perScreenApplied": "Egen bakgrunn satt på %d skjermer",
        "status.screenAssigned": "Favoritt satt på skjerm %d",
        "status.noImages": "Fant ingen bilder akkurat nå",
        "status.error": "Noe gikk galt: %@",
        "favorites.title": "Favoritter",
        "favorites.subtitle": "Lagrede bakgrunner du kan bruke igjen",
        "favorites.empty": "Ingen favoritter ennå. Trykk på hjertet i forhåndsvisningen for å lagre et bilde.",
        "favorites.toggle": "Legg til eller fjern favoritt",
        "favorites.apply": "Bruk som bakgrunn",
        "favorites.remove": "Fjern fra favoritter",
        "favorites.help": "Favoritter",
        "favorites.assign": "Tildel skjerm",
        "favorites.assignedScreens": "Skjerm %@",
        "screen.label": "Skjerm %d",
        "screen.labelPrimary": "Skjerm %d (hovedskjerm)",
        "theme.alle": "Alle",
        "theme.blomster": "Blomster",
        "theme.natur": "Natur",
        "theme.dyr": "Dyr",
        "theme.by": "By",
        "theme.landskap": "Landskap",
        "theme.hav": "Hav og vann",
        "theme.verdensrom": "Verdensrom",
        "theme.host": "Høst og vinter",
        "source.bing": "Bing Wallpaper",
        "source.spotlight": "Windows Spotlight"
    ]

    private static let english: [String: String] = [
        "tagline": "Random 4K wallpapers",
        "settings.source.title": "Image source",
        "settings.source.subtitle": "Choose where wallpapers come from",
        "settings.title": "Wallpaper theme",
        "settings.subtitle": "Choose which kind of images to fetch",
        "settings.imagesCount": "%d images",
        "settings.matchSummary": "%d of %d images match “%@”",
        "settings.spotlightNote": "Spotlight images are filtered by the selected theme too.",
        "settings.perscreen.title": "Wallpaper per screen",
        "settings.perscreen.subtitle": "Give each screen its own random image",
        "settings.perscreen.toggle": "Separate wallpaper per screen",
        "settings.help": "Settings",
        "settings.language.title": "Language",
        "settings.language.subtitle": "Choose the interface language",
        "button.new": "New wallpaper",
        "button.loading": "Fetching …",
        "preview.empty": "No wallpaper yet",
        "preview.ready": "Ready to fetch a wallpaper",
        "footer.count": "%d of %d images",
        "status.idle": "Click the button for a new wallpaper",
        "status.searching": "Searching for wallpapers …",
        "status.theme": "Theme: %@ – %d images",
        "status.fetching": "Fetching “%@” in 4K …",
        "status.downloading": "Downloading the 4K image …",
        "status.applied": "Wallpaper applied",
        "status.favoriteAdded": "Added to favorites",
        "status.favoriteRemoved": "Removed from favorites",
        "status.favoriteApplied": "Favorite applied as wallpaper",
        "status.screenProgress": "Fetching image %d of %d …",
        "status.perScreenApplied": "Separate wallpapers set on %d screens",
        "status.screenAssigned": "Favorite set on screen %d",
        "status.noImages": "No images found right now",
        "status.error": "Something went wrong: %@",
        "favorites.title": "Favorites",
        "favorites.subtitle": "Saved wallpapers you can reuse",
        "favorites.empty": "No favorites yet. Tap the heart on the preview to save an image.",
        "favorites.toggle": "Add or remove favorite",
        "favorites.apply": "Apply as wallpaper",
        "favorites.remove": "Remove from favorites",
        "favorites.help": "Favorites",
        "favorites.assign": "Assign to screen",
        "favorites.assignedScreens": "Screen %@",
        "screen.label": "Screen %d",
        "screen.labelPrimary": "Screen %d (primary)",
        "theme.alle": "All",
        "theme.blomster": "Flowers",
        "theme.natur": "Nature",
        "theme.dyr": "Animals",
        "theme.by": "City",
        "theme.landskap": "Landscape",
        "theme.hav": "Ocean & water",
        "theme.verdensrom": "Space",
        "theme.host": "Autumn & winter",
        "source.bing": "Bing Wallpaper",
        "source.spotlight": "Windows Spotlight"
    ]
}
