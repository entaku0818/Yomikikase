import Foundation
import ComposableArchitecture
import Dependencies

@Reducer
struct UserDictionaryReducer {
    @ObservableState
    struct State: Equatable {
        var entries: [UserDictionaryEntry] = []
        var word: String = ""
        var reading: String = ""
        var showingAddSheet: Bool = false
        var showingExportSheet: Bool = false
        var showingImportSheet: Bool = false
        var showingAlert: Bool = false
        var alertMessage: String = ""
        var isLoading: Bool = false
    }
    
    enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case entriesLoaded([UserDictionaryEntry])
        case exportCompleted(Result<Void, Error>)
        case importCompleted(Result<Data, Error>)
        
        enum View {
            case onAppear
            case addButtonTapped
            case addEntry
            case cancelAdd
            case deleteEntry(id: UUID)
            case exportButtonTapped
            case importButtonTapped
            case alertDismissed
        }
    }
    
    @Dependency(\.userDictionary) var userDictionary
    @Dependency(\.continuousClock) var clock
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .view(.onAppear):
                state.isLoading = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(500))
                    let entries = userDictionary.entries()
                    await send(.entriesLoaded(entries))
                }
                
            case .view(.addButtonTapped):
                state.showingAddSheet = true
                return .none
                
            case .view(.addEntry):
                guard !state.word.isEmpty && !state.reading.isEmpty else { return .none }
                userDictionary.addEntry(state.word, state.reading)
                state.entries = userDictionary.entries()
                state.word = ""
                state.reading = ""
                state.showingAddSheet = false
                return .none
                
            case .view(.cancelAdd):
                state.showingAddSheet = false
                state.word = ""
                state.reading = ""
                return .none
                
            case .view(.deleteEntry(let id)):
                userDictionary.removeEntry(id)
                state.entries = userDictionary.entries()
                return .none
                
            case .view(.exportButtonTapped):
                state.showingExportSheet = true
                return .none
                
            case .view(.importButtonTapped):
                state.showingImportSheet = true
                return .none
                
            case .view(.alertDismissed):
                state.showingAlert = false
                return .none
                
            case let .entriesLoaded(entries):
                state.entries = entries
                state.isLoading = false
                return .none
                
            case let .exportCompleted(result):
                state.showingExportSheet = false
                switch result {
                case .success:
                    state.alertMessage = "辞書をエクスポートしました"
                case .failure:
                    state.alertMessage = "エクスポートに失敗しました"
                }
                state.showingAlert = true
                return .none
                
            case let .importCompleted(result):
                state.showingImportSheet = false
                switch result {
                case .success(let data):
                    if userDictionary.importDictionary(data) {
                        state.entries = userDictionary.entries()
                        state.alertMessage = "辞書をインポートしました"
                    } else {
                        state.alertMessage = "インポートに失敗しました"
                    }
                case .failure:
                    state.alertMessage = "インポートに失敗しました"
                }
                state.showingAlert = true
                return .none
            }
        }
    }
} 
