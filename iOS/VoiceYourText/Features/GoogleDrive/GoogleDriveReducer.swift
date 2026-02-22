import ComposableArchitecture
import Foundation

@Reducer
struct GoogleDriveFeature {
    @ObservableState
    struct State: Equatable {
        var isSignedIn: Bool = false
        var isLoading: Bool = false
        var files: [GoogleDriveFile] = []
        var isLoadingFile: Bool = false
        var errorMessage: String? = nil
        var extractedText: String = ""
        var didExtractText: Bool = false
    }

    enum Action: ViewAction {
        case view(View)
        case filesLoaded([GoogleDriveFile])
        case fileTextLoaded(String)
        case errorOccurred(String)
        case signedIn
        case signedOut

        enum View {
            case onAppear
            case signInTapped
            case signOutTapped
            case fileTapped(GoogleDriveFile)
        }
    }

    @Dependency(\.googleDrive) var googleDrive

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear):
                state.isSignedIn = googleDrive.currentUser() != nil
                if state.isSignedIn {
                    state.isLoading = true
                    return loadFiles()
                }
                return .none

            case .view(.signInTapped):
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        try await googleDrive.signIn()
                        await send(.signedIn)
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .view(.signOutTapped):
                googleDrive.signOut()
                return .send(.signedOut)

            case .view(.fileTapped(let file)):
                state.isLoadingFile = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let text = try await googleDrive.fetchFileText(file)
                        await send(.fileTextLoaded(text))
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .signedIn:
                state.isSignedIn = true
                state.isLoading = true
                return loadFiles()

            case .signedOut:
                state.isSignedIn = false
                state.files = []
                return .none

            case .filesLoaded(let files):
                state.isLoading = false
                state.files = files
                return .none

            case .fileTextLoaded(let text):
                state.isLoadingFile = false
                state.extractedText = text
                state.didExtractText = true
                return .none

            case .errorOccurred(let message):
                state.isLoading = false
                state.isLoadingFile = false
                state.errorMessage = message
                return .none
            }
        }
    }

    private func loadFiles() -> Effect<Action> {
        .run { send in
            do {
                let files = try await googleDrive.listFiles()
                await send(.filesLoaded(files))
            } catch {
                await send(.errorOccurred(error.localizedDescription))
            }
        }
    }
}
