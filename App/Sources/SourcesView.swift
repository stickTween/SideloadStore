import SwiftUI

struct SourcesView: View {
    @EnvironmentObject private var store: SourceStore
    @State private var input = ""
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.urls, id: \.self) { url in
                        let source = store.sources.first { $0.url == url }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source?.name ?? url).font(.body.weight(.medium))
                            Text(url).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            if let count = source?.apps.count {
                                Text("Приложений: \(count)").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { store.remove(at: $0) }
                } footer: {
                    Text("Поддерживается формат манифеста AltStore/SideStore: JSON со списком apps и versions.")
                }

                if let error = store.lastError {
                    Section {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Источники")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await store.refresh() }
            .alert("Новый источник", isPresented: $showingAdd) {
                TextField("https://example.com/source.json", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Отмена", role: .cancel) { input = "" }
                Button("Добавить") {
                    let value = input
                    input = ""
                    Task { await store.add(value) }
                }
            }
        }
    }
}
