import SwiftUI
import AppKit

enum Palette {
    static let cream = Color(red: 0.99, green: 0.98, blue: 0.94)
    static let sky = Color(red: 0.91, green: 0.95, blue: 0.98)
    static let leafLight = Color(red: 0.90, green: 0.96, blue: 0.88)
    static let leaf = Color(red: 0.42, green: 0.66, blue: 0.42)
    static let leafDeep = Color(red: 0.24, green: 0.47, blue: 0.29)
    static let blossom = Color(red: 0.96, green: 0.72, blue: 0.78)
    static let petal = Color(red: 0.99, green: 0.90, blue: 0.92)
    static let ink = Color(red: 0.18, green: 0.24, blue: 0.19)
}

enum Glyph {
    static func first(_ names: [String]) -> String {
        names.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil } ?? "leaf.fill"
    }
    static let flower = first(["camera.macro", "laurel.leading", "leaf.fill"])
    static let leaf = first(["leaf.fill", "leaf"])
    static let sparkle = first(["sparkles", "wand.and.stars"])
    static let download = first(["arrow.down.circle.fill", "arrow.down.circle"])
}

struct ContentView: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject var loc: Localization
    @State private var showSettings = false
    @State private var showFavorites = false

    var body: some View {
        ZStack {
            background
            decorations
            content
        }
        .frame(width: 460, height: 660)
    }

    private var background: some View {
        LinearGradient(
            colors: [Palette.cream, Palette.leafLight, Palette.sky, Palette.petal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var decorations: some View {
        ZStack {
            Image(systemName: Glyph.flower)
                .font(.system(size: 190))
                .foregroundStyle(Palette.leaf.opacity(0.10))
                .rotationEffect(.degrees(-18))
                .offset(x: -150, y: -250)

            Image(systemName: Glyph.leaf)
                .font(.system(size: 150))
                .foregroundStyle(Palette.blossom.opacity(0.18))
                .rotationEffect(.degrees(28))
                .offset(x: 165, y: -215)

            Image(systemName: Glyph.leaf)
                .font(.system(size: 170))
                .foregroundStyle(Palette.leafDeep.opacity(0.08))
                .rotationEffect(.degrees(-40))
                .offset(x: 150, y: 275)

            Image(systemName: Glyph.flower)
                .font(.system(size: 130))
                .foregroundStyle(Palette.leafDeep.opacity(0.09))
                .rotationEffect(.degrees(12))
                .offset(x: -165, y: 280)
        }
        .allowsHitTesting(false)
    }

    private var content: some View {
        VStack(spacing: 18) {
            header
            previewCard
            caption
            actionButton
            statusView
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 18)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Palette.leaf, Palette.leafDeep],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: Palette.leafDeep.opacity(0.35), radius: 8, y: 4)
                Image(systemName: Glyph.flower)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Villblomst")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("\(loc.t("tagline")) · \(store.selectedThemeName)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.leafDeep.opacity(0.8))
            }
            Spacer()
            Button {
                showFavorites.toggle()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: store.favorites.isEmpty ? "heart" : "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(store.favorites.isEmpty ? Palette.leafDeep : Palette.blossom)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.85)))
                        .overlay(Circle().strokeBorder(Palette.leaf.opacity(0.3), lineWidth: 1))
                    if !store.favorites.isEmpty {
                        Text("\(store.favorites.count)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Palette.leafDeep))
                            .offset(x: 4, y: -3)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(loc.t("favorites.help"))
            .popover(isPresented: $showFavorites, arrowEdge: .top) {
                FavoritesView(store: store, loc: loc)
            }
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.leafDeep)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.85)))
                    .overlay(Circle().strokeBorder(Palette.leaf.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help(loc.t("settings.help"))
            .popover(isPresented: $showSettings, arrowEdge: .top) {
                SettingsView(store: store, loc: loc)
            }
        }
    }

    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.85))
            if let image = store.preview {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: 404, height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.leaf.opacity(0.25), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if !store.wallpaperTitle.isEmpty {
                Button {
                    store.toggleFavorite()
                } label: {
                    Image(systemName: store.isCurrentFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(store.isCurrentFavorite ? Palette.blossom : .white)
                        .padding(9)
                        .background(Circle().fill(.black.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .padding(12)
                .help(loc.t("favorites.toggle"))
            }
        }
        .shadow(color: Palette.leafDeep.opacity(0.18), radius: 16, y: 8)
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: Glyph.flower)
                .font(.system(size: 58))
                .foregroundStyle(Palette.leaf.opacity(0.6))
            Text(loc.t("preview.empty"))
                .font(.system(.callout, design: .rounded).weight(.medium))
                .foregroundStyle(Palette.ink.opacity(0.65))
        }
    }

    private var caption: some View {
        Text(store.wallpaperTitle.isEmpty ? loc.t("preview.ready") : store.wallpaperTitle)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Palette.ink.opacity(0.72))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(minHeight: 34, alignment: .center)
            .padding(.horizontal, 4)
    }

    private var actionButton: some View {
        Button {
            Task { await store.next() }
        } label: {
            HStack(spacing: 10) {
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: Glyph.sparkle)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(loc.t(store.isLoading ? "button.loading" : "button.new"))
                    .font(.system(.headline, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(colors: [Palette.leaf, Palette.leafDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Palette.leafDeep.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading || store.isPreparing)
        .opacity(store.isLoading || store.isPreparing ? 0.75 : 1)
    }

    private var statusView: some View {
        HStack(spacing: 7) {
            if store.isPreparing {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: Glyph.leaf)
                    .font(.system(size: 11))
            }
            Text(store.status)
                .font(.system(.caption, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Palette.leafDeep.opacity(0.85))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack {
            Text("bingwallpaper.anerg.com")
                .font(.system(.caption2, design: .rounded))
            Spacer()
            if store.totalCount > 0 {
                Text(String(format: loc.t("footer.count"), store.poolCount, store.totalCount))
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .foregroundStyle(Palette.ink.opacity(0.45))
    }
}
