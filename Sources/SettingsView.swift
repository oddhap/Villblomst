import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: WallpaperStore

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Bakgrunnstema")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("Velg hvilke bilder som skal hentes fra Bing")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(store.themes) { theme in
                    ThemeCard(
                        theme: theme,
                        selected: theme.id == store.selectedThemeID,
                        count: store.themeCounts[theme.id] ?? 0
                    ) {
                        store.select(theme)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 12))
                Text("\(store.poolCount) av \(store.totalCount) bilder passer til «\(store.selectedThemeName)»")
                    .font(.system(.caption, design: .rounded))
            }
            .foregroundStyle(Palette.ink.opacity(0.6))
        }
        .padding(18)
        .frame(width: 400)
        .background(Palette.cream)
    }
}

private struct ThemeCard: View {
    let theme: WallpaperTheme
    let selected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: theme.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? .white : Palette.leafDeep)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                    }
                }
                Text(theme.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(selected ? .white : Palette.ink)
                Text("\(count) bilder")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(selected ? .white.opacity(0.85) : Palette.ink.opacity(0.55))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.leaf.opacity(selected ? 0 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        if selected {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Palette.leaf, Palette.leafDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Palette.leafDeep.opacity(0.3), radius: 6, y: 3)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.9))
        }
    }
}
