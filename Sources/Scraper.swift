import Foundation

struct Wallpaper: Codable, Hashable {
    let slug: String
    let title: String
}

enum ScraperError: Error, LocalizedError {
    case http(Int)
    case noImage
    case badURL

    var errorDescription: String? {
        switch self {
        case .http(let code): return "Nettsiden svarte med HTTP \(code)"
        case .noImage: return "Fant ikke 4K-bildet"
        case .badURL: return "Ugyldig lenke"
        }
    }
}

struct Scraper {
    static let base = "https://bingwallpaper.anerg.com"
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    // Noen faste favoritter i tilfelle nettet ikke er tilgjengelig første gang.
    static let fallback: [Wallpaper] = [
        Wallpaper(slug: "WildflowerValley", title: "Wildflower bloom, Central Valley, California"),
        Wallpaper(slug: "RilaCrocuses", title: "Purple crocus flowers, Seven Rila Lakes, Bulgaria"),
        Wallpaper(slug: "LupineBloom", title: "Lupine flowers in bloom, Northern California"),
        Wallpaper(slug: "DutchTulips", title: "Grape hyacinths and tulips, Keukenhof Gardens, Netherlands"),
        Wallpaper(slug: "HoneyBeeLavender", title: "Honey bee on lavender flowers"),
        Wallpaper(slug: "PinkDahlia", title: "Pink dahlia flower"),
        Wallpaper(slug: "HertfordshireBluebells", title: "A path through a bluebell forest, England"),
        Wallpaper(slug: "WildLupine", title: "Wild lupines in bloom"),
        Wallpaper(slug: "HwangmaesanAzaleas", title: "Royal azaleas on Hwangmaesan Mountain, South Korea"),
        Wallpaper(slug: "RainierWildflowers", title: "Wildflowers in Mount Rainier National Park")
    ]

    /// Siste `back` måneder som "yyyyMM", nyeste først.
    static func monthStrings(back: Int, from date: Date = Date()) -> [String] {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        var year = comps.year ?? 2026
        var month = comps.month ?? 1
        var out: [String] = []
        for _ in 0..<back {
            out.append(String(format: "%04d%02d", year, month))
            month -= 1
            if month == 0 { month = 12; year -= 1 }
        }
        return out
    }

    static func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 90
        cfg.httpAdditionalHeaders = ["User-Agent": userAgent]
        return URLSession(configuration: cfg)
    }

    static func fetchHTML(_ url: URL, session: URLSession) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ScraperError.http(http.statusCode)
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func fetchArchive(month: String, session: URLSession) async -> [Wallpaper] {
        guard let url = URL(string: "\(base)/archive/us/\(month)") else { return [] }
        guard let html = try? await fetchHTML(url, session: session) else { return [] }
        return parseAnchors(html)
    }

    static func parseAnchors(_ html: String) -> [Wallpaper] {
        let pattern = "href=\"/detail/us/([^\"]+)\"[^>]*?data-bs-title=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
        var out: [Wallpaper] = []
        for m in matches where m.numberOfRanges == 3 {
            let slug = ns.substring(with: m.range(at: 1))
            let title = decodeHTML(ns.substring(with: m.range(at: 2)))
            out.append(Wallpaper(slug: slug, title: title))
        }
        return out
    }

    /// Henter alle arkivsider og returnerer alle unike bakgrunner.
    static func pool(months: [String], session: URLSession) async -> [Wallpaper] {
        var bySlug: [String: Wallpaper] = [:]
        await withTaskGroup(of: [Wallpaper].self) { group in
            var next = 0
            let maxConcurrent = 6
            func enqueue() {
                guard next < months.count else { return }
                let month = months[next]
                next += 1
                group.addTask { await fetchArchive(month: month, session: session) }
            }
            for _ in 0..<maxConcurrent { enqueue() }
            for await list in group {
                for item in list {
                    bySlug[item.slug] = item
                }
                enqueue()
            }
        }
        return bySlug.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func detail4KURL(slug: String, session: URLSession) async throws -> URL {
        guard let url = URL(string: "\(base)/detail/us/\(slug)") else { throw ScraperError.badURL }
        let html = try await fetchHTML(url, session: session)
        let pattern = "https://imgproxy\\.nanxiongnandi\\.com/[^\"']*w:3840[^\"']*"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
              let found = URL(string: (html as NSString).substring(with: match.range)) else {
            throw ScraperError.noImage
        }
        return found
    }

    static func download(_ url: URL, to destination: URL, session: URLSession) async throws {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ScraperError.http(http.statusCode)
        }
        try data.write(to: destination, options: .atomic)
    }

    static func decodeHTML(_ input: String) -> String {
        var s = input
        let named = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
                     "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&#43;": "+"]
        for (k, v) in named { s = s.replacingOccurrences(of: k, with: v) }
        if let regex = try? NSRegularExpression(pattern: "&#(x?[0-9A-Fa-f]+);") {
            let ns = s as NSString
            let matches = regex.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
            for m in matches.reversed() {
                let raw = ns.substring(with: m.range(at: 1))
                let value: UInt32?
                if raw.hasPrefix("x") || raw.hasPrefix("X") {
                    value = UInt32(raw.dropFirst(), radix: 16)
                } else {
                    value = UInt32(raw)
                }
                if let v = value, let scalar = Unicode.Scalar(v) {
                    s = (s as NSString).replacingCharacters(in: m.range, with: String(Character(scalar)))
                }
            }
        }
        return s
    }
}
