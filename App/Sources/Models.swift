import Foundation

struct AppVersion: Codable, Hashable {
    var version: String
    var date: String?
    var localizedDescription: String?
    var downloadURL: String
    var size: Int?
    var minOSVersion: String?
}

struct StoreApp: Codable, Hashable, Identifiable {
    var name: String
    var bundleIdentifier: String
    var developerName: String?
    var subtitle: String?
    var localizedDescription: String?
    var iconURL: String?
    var tintColor: String?
    var screenshotURLs: [String]?
    var version: String?
    var versionDate: String?
    var downloadURL: String?
    var size: Int?
    var versions: [AppVersion]?

    var id: String { bundleIdentifier }

    var latest: AppVersion? {
        if let v = versions?.first { return v }
        guard let url = downloadURL else { return nil }
        return AppVersion(version: version ?? "1.0",
                          date: versionDate,
                          localizedDescription: localizedDescription,
                          downloadURL: url,
                          size: size,
                          minOSVersion: nil)
    }
}

struct SourcePayload: Codable {
    var name: String?
    var identifier: String?
    var subtitle: String?
    var description: String?
    var iconURL: String?
    var website: String?
    var tintColor: String?
    var apps: [StoreApp]?
}

struct AppSource: Identifiable, Hashable {
    var url: String
    var name: String
    var subtitle: String?
    var iconURL: String?
    var tintColor: String?
    var apps: [StoreApp]

    var id: String { url }

    static func make(url: String, payload: SourcePayload) -> AppSource {
        AppSource(url: url,
                  name: payload.name ?? URL(string: url)?.host ?? url,
                  subtitle: payload.subtitle ?? payload.description,
                  iconURL: payload.iconURL,
                  tintColor: payload.tintColor,
                  apps: payload.apps ?? [])
    }
}

struct LocalPackage: Identifiable, Hashable {
    var url: URL
    var size: Int64
    var date: Date

    var id: String { url.path }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

enum Formatter2 {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func bytes(_ value: Int?) -> String? {
        guard let value else { return nil }
        return bytes(Int64(value))
    }
}
