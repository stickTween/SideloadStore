import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: Library
    @State private var importing = false
    @State private var shareItem: URL?
    @State private var installTarget: LocalPackage?

    private var ipaType: UTType {
        UTType(filenameExtension: "ipa") ?? .data
    }

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
                                    shareItem = package.url
                                } label: { Label("Поделиться", systemImage: "square.and.arrow.up") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Библиотека")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }
                }
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [ipaType],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    library.importFile(url)
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
                    shareItem = installTarget?.url
                    installTarget = nil
                }
                Button("Отмена", role: .cancel) { installTarget = nil }
            }
            .sheet(item: Binding(
                get: { shareItem.map { ShareBox(url: $0) } },
                set: { shareItem = $0?.url }
            )) { box in
                ShareSheet(url: box.url)
            }
        }
    }
}

struct ShareBox: Identifiable {
    var url: URL
    var id: String { url.path }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
