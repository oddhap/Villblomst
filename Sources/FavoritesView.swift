import SwiftUI

struct FavoritesView: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject var loc: Localization

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(loc.t("favorites.title"))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(loc.t("favorites.subtitle"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }

            if store.favorites.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.favorites) { favorite in
                            FavoriteTile(store: store, loc: loc, favorite: favorite)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 340)
            }
        }
        .padding(18)
        .frame(width: 400)
        .background(Palette.cream)
        .task { store.loadFavoriteThumbnails() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 34))
                .foregroundStyle(Palette.blossom)
            Text(loc.t("favorites.empty"))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct FavoriteTile: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject var loc: Localization
    let favorite: Favorite

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let thumb = store.favoriteThumbnails[favorite.slug] {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Palette.leafLight)
                        .overlay(ProgressView().controlSize(.small))
                }
            }
            .frame(width: 108, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button {
                    store.removeFavorite(favorite)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .padding(5)
                .help(loc.t("favorites.remove"))
            }
            .overlay(alignment: .topLeading) {
                if store.screenCount > 1 {
                    Menu {
                        ForEach(Array(0..<store.screenCount), id: \.self) { index in
                            Button(store.screenLabel(index)) {
                                Task { await store.assign(favorite, toScreen: index) }
                            }
                        }
                    } label: {
                        Image(systemName: "display")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .padding(5)
                    .help(loc.t("favorites.assign"))
                }
            }

            Text(favorite.title)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !assignedScreens.isEmpty {
                Text(String(format: loc.t("favorites.assignedScreens"),
                            assignedScreens.map { String($0 + 1) }.joined(separator: ", ")))
                    .font(.system(size: 9, design: .rounded).weight(.medium))
                    .foregroundStyle(Palette.leafDeep)
                    .lineLimit(1)
            }
        }
        .frame(width: 108, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await store.applyFavorite(favorite) }
        }
        .help(loc.t("favorites.apply"))
    }

    private var assignedScreens: [Int] {
        store.assignedScreenNumbers(for: favorite)
    }
}
