import Foundation
import Combine

@MainActor
final class Library: NSObject, ObservableObject {
    @Published private(set) var packages: [LocalPackage] = []
    @Published var progress: [String: Double] = [:]
    @Published var activeName: String?
    @Published var errorMessage: String?

    private var session: URLSession!
    private var tasks: [Int: String] = [:]

    static let directory: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Packages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        reload()
    }

    func reload() {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: Self.directory,
                                                 includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        packages = items
            .filter { $0.pathExtension.lowercased() == "ipa" }
            .map { url in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                return LocalPackage(url: url,
                                    size: Int64(values?.fileSize ?? 0),
                                    date: values?.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.date > $1.date }
    }

    func download(app: StoreApp, version: AppVersion) {
        guard let url = URL(string: version.downloadURL) else {
            errorMessage = "Некорректная ссылка на IPA"
            return
        }
        let name = "\(app.name)-\(version.version).ipa".replacingOccurrences(of: "/", with: "-")
        let task = session.downloadTask(with: url)
        tasks[task.taskIdentifier] = name
        activeName = name
        progress[name] = 0
        task.resume()
    }

    func importFile(_ source: URL) {
        let needsStop = source.startAccessingSecurityScopedResource()
        defer { if needsStop { source.stopAccessingSecurityScopedResource() } }
        let target = Self.directory.appendingPathComponent(source.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: source, to: target)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ package: LocalPackage) {
        try? FileManager.default.removeItem(at: package.url)
        reload()
    }

    fileprivate func finish(name: String, temp: URL) {
        let target = Self.directory.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.moveItem(at: temp, to: target)
        } catch {
            errorMessage = error.localizedDescription
        }
        progress[name] = nil
        if activeName == name { activeName = nil }
        reload()
    }
}

extension Library: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                               downloadTask: URLSessionDownloadTask,
                               didFinishDownloadingTo location: URL) {
        let staged = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.moveItem(at: location, to: staged)
        let identifier = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let name = self.tasks.removeValue(forKey: identifier) else { return }
            self.finish(name: name, temp: staged)
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                               downloadTask: URLSessionDownloadTask,
                               didWriteData bytesWritten: Int64,
                               totalBytesWritten: Int64,
                               totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let value = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let identifier = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let name = self.tasks[identifier] else { return }
            self.progress[name] = value
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                               task: URLSessionTask,
                               didCompleteWithError error: Error?) {
        guard let error else { return }
        let identifier = task.taskIdentifier
        Task { @MainActor in
            if let name = self.tasks.removeValue(forKey: identifier) {
                self.progress[name] = nil
                if self.activeName == name { self.activeName = nil }
            }
            self.errorMessage = error.localizedDescription
        }
    }
}
