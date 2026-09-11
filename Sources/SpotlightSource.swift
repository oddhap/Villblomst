import Foundation

// Windows Spotlight image source.
//
// The endpoint and response format are based on the excellent research in
// ORelio's Spotlight-Downloader (https://github.com/ORelio/Spotlight-Downloader),
// released under CDDL-1.0. This file is an independent Swift re-implementation
// of the v4 "selection" API used there.
enum WallpaperSource: String, CaseIterable, Identifiable {
    case bing
    case spotlight

    var id: String { rawValue }
}

struct SpotlightImage: Hashable {
    let id: String
    let url: URL
    let title: String
    let copyright: String

    var searchText: String { "\(title) \(copyright)" }

    var displayTitle: String {
        copyright.isEmpty ? title : "\(title) (\(copyright))"
    }
}

enum SpotlightAPI {
    static func localeInfo() -> (locale: String, country: String) {
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        let normalized = preferred.replacingOccurrences(of: "_", with: "-")
        let parts = normalized.split(separator: "-")
        let country = parts.count > 1 ? String(parts[1]).uppercased() : "US"
        let locale = parts.count > 1 ? normalized : "\(normalized)-\(country)"
        return (locale, country)
    }

    /// Requests one batch (up to four images) from the Spotlight API.
    static func fetchOnce(locale: String, country: String, session: URLSession) async throws -> [SpotlightImage] {
        guard let url = URL(string:
            "https://fd.api.iris.microsoft.com/v4/api/selection"
            + "?&placement=88000820&bcnt=4&country=\(country)&locale=\(locale)&fmt=json") else {
            throw ScraperError.badURL
        }
        var request = URLRequest(url: url)
        request.setValue(Scraper.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ScraperError.http(http.statusCode)
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let batch = root["batchrsp"] as? [String: Any],
              let items = batch["items"] as? [[String: Any]] else {
            throw ScraperError.noImage
        }

        var images: [SpotlightImage] = []
        for wrapper in items {
            guard let itemString = wrapper["item"] as? String,
                  let itemData = itemString.data(using: .utf8),
                  let inner = try? JSONSerialization.jsonObject(with: itemData) as? [String: Any],
                  let ad = inner["ad"] as? [String: Any],
                  let landscape = ad["landscapeImage"] as? [String: Any],
                  let asset = landscape["asset"] as? String,
                  let assetURL = URL(string: asset) else { continue }

            let title = firstLine(ad["iconHoverText"] as? String) ?? cleanTitle(ad["title"] as? String) ?? ""
            let copyright = (ad["copyright"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let id = assetURL.deletingPathExtension().lastPathComponent
            guard !id.isEmpty else { continue }

            images.append(SpotlightImage(id: id, url: assetURL, title: title, copyright: copyright))
        }
        return images
    }

    private static func cleanTitle(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func firstLine(_ value: String?) -> String? {
        guard let value else { return nil }
        let line = value
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (line?.isEmpty ?? true) ? nil : line
    }
}
