import Foundation

@MainActor
final class SourceStore: ObservableObject {
    @Published private(set) var sources: [AppSource] = []
    @Published private(set) var urls: [String] = []
    @Published var isRefreshing = false
    @Published var lastError: String?

    private let key = "source_urls"

    init() {
        urls = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    var allApps: [StoreApp] {
        sources.flatMap { $0.apps }
    }

    func add(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else {
            lastError = "Некорректный URL"
            return
        }
        guard !urls.contains(trimmed) else { return }
        urls.append(trimmed)
        persist()
        await refresh()
    }

    func remove(at offsets: IndexSet) {
        urls.remove(atOffsets: offsets)
        persist()
        sources = sources.filter { urls.contains($0.url) }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        var loaded: [AppSource] = []
        var failures: [String] = []

        await withTaskGroup(of: (String, SourcePayload?).self) { group in
            for url in urls {
                group.addTask { (url, await Self.fetch(url)) }
            }
            for await (url, payload) in group {
                if let payload {
                    loaded.append(AppSource.make(url: url, payload: payload))
                } else {
                    failures.append(url)
                }
            }
        }

        sources = urls.compactMap { url in loaded.first { $0.url == url } }
        if !failures.isEmpty {
            lastError = "Не загружено источников: \(failures.count)"
        }
        isRefreshing = false
    }

    private func persist() {
        UserDefaults.standard.set(urls, forKey: key)
    }

    private static func fetch(_ url: String) async -> SourcePayload? {
        guard let link = URL(string: url) else { return nil }
        var request = URLRequest(url: link)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            return try JSONDecoder().decode(SourcePayload.self, from: data)
        } catch {
            return nil
        }
    }
}
