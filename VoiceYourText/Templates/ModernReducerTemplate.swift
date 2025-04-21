import SwiftUI
import ComposableArchitecture

@Reducer
struct FeatureReducer {
  @ObservableState
  struct State: Equatable {
    var items: [Item] = []
    var searchQuery: String = ""
    var isLoading: Bool = false
  }

  struct Item: Identifiable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var isFavorite: Bool = false

    init(id: UUID = UUID(), title: String, description: String) {
      self.id = id
      self.title = title
      self.description = description
    }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case itemTapped(Item.ID)
    case toggleFavorite(Item.ID)
    case loadItems
    case itemsLoaded([Item])
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .itemTapped(id):
        // ここに処理を追加
        return .none

      case let .toggleFavorite(id):
        if let index = state.items.firstIndex(where: { $0.id == id }) {
          state.items[index].isFavorite.toggle()
        }
        return .none

      case .loadItems:
        state.isLoading = true
        return .run { send in
          // データのロードをシミュレート
          try await clock.sleep(for: .seconds(1))

          let items = [
            Item(title: "アイテム1", description: "説明1"),
            Item(title: "アイテム2", description: "説明2"),
            Item(title: "アイテム3", description: "説明3")
          ]

          await send(.itemsLoaded(items))
        }

      case let .itemsLoaded(items):
        state.items = items
        state.isLoading = false
        return .none
      }
    }
  }
}

struct FeatureView: View {
    @Perception.Bindable var store: StoreOf<FeatureReducer>

  var body: some View {
    NavigationStack {
      VStack {
        // 検索フィールド
          HStack {
            Image(systemName: "magnifyingglass")
              .foregroundColor(.gray)
            TextField("検索...", text: $store.searchQuery)
            .textFieldStyle(.roundedBorder)
          }
          .padding(.horizontal)


        // リスト
        List {
          ForEach(store.items.filter {
            store.searchQuery.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(store.searchQuery)
          }) { item in
            HStack {
              VStack(alignment: .leading) {
                Text(item.title)
                  .font(.headline)
                Text(item.description)
                  .font(.subheadline)
                  .foregroundColor(.gray)
              }

              Spacer()

              Button {
                store.send(.toggleFavorite(item.id))
              } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                  .foregroundColor(item.isFavorite ? .yellow : .gray)
              }
              .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
              store.send(.itemTapped(item.id))
            }
          }
        }
        .listStyle(.plain)
        .overlay {
          if store.isLoading {
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(Color.black.opacity(0.2))
          }
        }
      }
      .navigationTitle("機能名")
      .onAppear {
        store.send(.loadItems)
      }
    }
  }
}

#Preview {
  FeatureView(
    store: Store(initialState: FeatureReducer.State()) {
      FeatureReducer()
    }
  )
}
