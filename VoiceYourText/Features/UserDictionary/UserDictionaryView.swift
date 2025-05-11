import SwiftUI
import ComposableArchitecture

@ViewAction(for: UserDictionaryReducer.self)
struct UserDictionaryView: View {
    @Perception.Bindable var store: StoreOf<UserDictionaryReducer>

    var body: some View {
        NavigationView {
            DictionaryListView(
                entries: store.entries,
                onDelete: { id in
                    send(.deleteEntry(id: id))
                }
            )
            .navigationTitle("ユーザー辞書")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { send(.addButtonTapped) }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if UserDefaultsManager.shared.isPremiumUser {
                        DictionaryMenu(
                            onExport: { send(.exportButtonTapped) },
                            onImport: { send(.importButtonTapped) }
                        )
                    } else {
                        Menu {
                            Button(action: {
                                // プレミアム機能の購入画面に遷移
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootViewController = windowScene.windows.first?.rootViewController {
                                    let subscriptionView = SubscriptionView()
                                    let hostingController = UIHostingController(rootView: subscriptionView)
                                    rootViewController.present(hostingController, animated: true)
                                }
                            }) {
                                Label("プレミアム機能を購入", systemImage: "star.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $store.showingAddSheet) {
                AddEntrySheet(
                    word: $store.word,
                    reading: $store.reading,
                    onCancel: { send(.cancelAdd) },
                    onAdd: { send(.addEntry) }
                )
            }
            .alert("通知", isPresented: $store.showingAlert) {
                Button("OK") {
                    send(.alertDismissed)
                }
            } message: {
                Text(store.alertMessage)
            }
        }
        .onAppear {
            send(.onAppear)
        }
    }
}

private struct DictionaryListView: View {
    let entries: [UserDictionaryEntry]
    let onDelete: (UUID) -> Void
    
    var body: some View {
        List {
            ForEach(entries) { entry in
                DictionaryEntryRow(entry: entry)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    onDelete(entries[index].id)
                }
            }
        }
    }
}

private struct DictionaryEntryRow: View {
    let entry: UserDictionaryEntry
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.word)
                .font(.headline)
            Text(entry.reading)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

private struct DictionaryMenu: View {
    let onExport: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        Menu {
            Button(action: onExport) {
                Label("エクスポート", systemImage: "square.and.arrow.up")
            }
            Button(action: onImport) {
                Label("インポート", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

private struct AddEntrySheet: View {
    @Binding var word: String
    @Binding var reading: String
    let onCancel: () -> Void
    let onAdd: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("単語")) {
                    TextField("単語", text: $word)
                }
                Section(header: Text("読み方")) {
                    TextField("読み方", text: $reading)
                }
            }
            .navigationTitle("単語を追加")
            .navigationBarItems(
                leading: Button("キャンセル", action: onCancel),
                trailing: Button("追加", action: onAdd)
            )
        }
    }
}

#Preview {
    UserDictionaryView(
        store: Store(
            initialState: UserDictionaryReducer.State(),
            reducer: { UserDictionaryReducer() }
        )
    )
} 
