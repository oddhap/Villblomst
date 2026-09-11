import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject var loc: Localization

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader(loc.t("settings.source.title"), loc.t("settings.source.subtitle"))
                HStack(spacing: 8) {
                    ForEach(WallpaperSource.allCases) { source in
                        Button {
                            store.selectSource(source)
                        } label: {
                            Text(loc.t("source.\(source.rawValue)"))
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(store.source == source ? .white : Palette.leafDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectionBackground(selected: store.source == source))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                sectionHeader(loc.t("settings.title"), loc.t("settings.subtitle"))
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.themes) { theme in
                        ThemeCard(
                            theme: theme,
                            name: loc.themeName(theme.id),
                            countLabel: store.source == .bing
                                ? String(format: loc.t("settings.imagesCount"), store.themeCounts[theme.id] ?? 0)
                                : "",
                            selected: theme.id == store.selectedThemeID
                        ) {
                            store.select(theme)
                        }
                    }
                }
                .padding(.top, 6)
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: store.source == .bing ? "photo.on.rectangle.angled" : "info.circle")
                    .font(.system(size: 12))
                Text(store.source == .bing
                     ? String(format: loc.t("settings.matchSummary"),
                              store.poolCount, store.totalCount, store.selectedThemeName)
                     : loc.t("settings.spotlightNote"))
                    .font(.system(.caption, design: .rounded))
            }
            .foregroundStyle(Palette.ink.opacity(0.6))

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                sectionHeader(loc.t("settings.language.title"), loc.t("settings.language.subtitle"))
                HStack(spacing: 8) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            loc.language = language
                        } label: {
                            Text(language.label)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(loc.language == language ? .white : Palette.leafDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectionBackground(selected: loc.language == language))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(width: 400)
        .background(Palette.cream)
    }

    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.6))
        }
    }

    @ViewBuilder
    private func selectionBackground(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Palette.leaf, Palette.leafDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Palette.leaf.opacity(0.25), lineWidth: 1)
                )
        }
    }
}

private struct ThemeCard: View {
    let theme: WallpaperTheme
    let name: String
    let countLabel: String
    let selected: Bool
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
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(selected ? .white : Palette.ink)
                if !countLabel.isEmpty {
                    Text(countLabel)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(selected ? .white.opacity(0.85) : Palette.ink.opacity(0.55))
                }
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
