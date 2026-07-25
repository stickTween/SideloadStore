import SwiftUI

enum LibrarySheet: Identifiable {
    case importer
    case share(URL)

    var id: String {
        switch self {
        case .importer: return "importer"
        case .share(let url): return url.path
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var library: Library
    @State private var sheet: LibrarySheet?
    @State private var installTarget: LocalPackage?

    var body: some View {
        NavigationStack {
            Group {
                if library.packages.isEmpty {
                    EmptyStateView(icon: "tray",
                                   title: "Библиотека пуста",
                                   message: "Скачай приложение из каталога или импортируй свой IPA.")
                } else {
                    List {
                        ForEach(library.packages) { package in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(package.name).font(.body.weight(.medium)).lineLimit(2)
                                Text(Formatter2.bytes(package.size))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { installTarget = package }
                            .swipeActions {
                                Button(role: .destructive) {
                                    library.delete(package)
                                } label: { Label("Удалить", systemImage: "trash") }
                                Button {
                                    sheet = .share(package.url)
                                } label: { Label("Поделиться", systemImage: "square.and.arrow.up") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Библиотека")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .importer } label: { Image(systemName: "square.and.arrow.down") }
                }
            }
            .sheet(item: $sheet) { route in
                switch route {
                case .importer:
                    DocumentPicker { url in
                        library.importFile(url)
                        sheet = nil
                    }
                    .ignoresSafeArea()
                case .share(let url):
                    ShareSheet(url: url)
                }
            }
            .confirmationDialog("Установить через", isPresented: Binding(
                get: { installTarget != nil },
                set: { if !$0 { installTarget = nil } }
            ), titleVisibility: .visible) {
                ForEach(Installer.available) { target in
                    Button(target.title) {
                        if let package = installTarget {
                            _ = Installer.handoff(local: package.url, to: target)
                        }
                        installTarget = nil
                    }
                }
                Button("Открыть в…") {
                    if let package = installTarget {
                        installTarget = nil
                        sheet = .share(package.url)
                    }
                }
                Button("Отмена", role: .cancel) { installTarget = nil }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { library.errorMessage = nil }
            } message: {
                Text(library.errorMessage ?? "")
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
