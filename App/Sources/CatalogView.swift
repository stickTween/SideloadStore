import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var store: SourceStore
    @State private var query = ""

    private var results: [(source: AppSource, apps: [StoreApp])] {
        store.sources.compactMap { source in
            let apps = query.isEmpty ? source.apps : source.apps.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                || ($0.developerName ?? "").localizedCaseInsensitiveContains(query)
            }
            return apps.isEmpty ? nil : (source, apps)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.urls.isEmpty {
                    EmptyStateView(icon: "antenna.radiowaves.left.and.right",
                                   title: "Нет источников",
                                   message: "Добавь ссылку на репозиторий во вкладке «Источники».")
                } else if results.isEmpty {
                    EmptyStateView(icon: "magnifyingglass",
                                   title: "Ничего не найдено",
                                   message: store.isRefreshing ? "Загрузка…" : "Потяни вниз, чтобы обновить.")
                } else {
                    List {
                        ForEach(results, id: \.source.id) { entry in
                            Section(entry.source.name) {
                                ForEach(entry.apps) { app in
                                    NavigationLink(value: app) {
                                        AppRow(app: app)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Каталог")
            .navigationDestination(for: StoreApp.self) { AppDetailView(app: $0) }
            .searchable(text: $query, prompt: "Поиск приложений")
            .refreshable { await store.refresh() }
        }
    }
}

struct AppRow: View {
    let app: StoreApp

    var body: some View {
        HStack(spacing: 12) {
            IconView(url: app.iconURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.body.weight(.medium))
                if let subtitle = app.subtitle ?? app.developerName {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if let version = app.latest?.version {
                Text(version).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct IconView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: URL(string: url ?? "")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AppDetailView: View {
    let app: StoreApp
    @EnvironmentObject private var library: Library
    @State private var selected: AppVersion?

    private var versions: [AppVersion] {
        if let list = app.versions, !list.isEmpty { return list }
        return app.latest.map { [$0] } ?? []
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    IconView(url: app.iconURL, size: 68)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name).font(.title3.bold())
                        if let developer = app.developerName {
                            Text(developer).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(app.bundleIdentifier).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }

            if let description = app.localizedDescription, !description.isEmpty {
                Section("Описание") {
                    Text(description).font(.subheadline)
                }
            }

            Section("Версии") {
                ForEach(versions, id: \.version) { version in
                    Button {
                        library.download(app: app, version: version)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(version.version)
                                if let size = Formatter2.bytes(version.size) {
                                    Text(size).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                        }
                    }
                }
            }

            if let active = library.activeName, let value = library.progress[active] {
                Section("Загрузка") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(active).font(.caption).lineLimit(1)
                        ProgressView(value: value)
                    }
                }
            }
        }
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
