import UIKit

enum Installer {
    struct Target: Identifiable {
        var id: String { scheme }
        var scheme: String
        var title: String
    }

    static let targets: [Target] = [
        Target(scheme: "esign", title: "ESign"),
        Target(scheme: "feather", title: "Feather"),
        Target(scheme: "sidestore", title: "SideStore"),
        Target(scheme: "altstore", title: "AltStore")
    ]

    static var available: [Target] {
        targets.filter { target in
            guard let url = URL(string: "\(target.scheme)://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    static func handoff(remote: String, to target: Target) -> Bool {
        guard let encoded = remote.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "\(target.scheme)://install?url=\(encoded)") else { return false }
        UIApplication.shared.open(url)
        return true
    }

    static func handoff(local: URL, to target: Target) -> Bool {
        guard let encoded = local.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "\(target.scheme)://install?url=\(encoded)") else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
