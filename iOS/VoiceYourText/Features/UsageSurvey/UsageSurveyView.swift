import SwiftUI
import ComposableArchitecture

@ViewAction(for: UsageSurveyFeature.self)
struct UsageSurveyView: View {
    @Environment(\.dismiss) private var dismiss
    @State var store = Store(initialState: UsageSurveyFeature.State()) { UsageSurveyFeature() }

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Text("survey.introduction")
                Text("survey.optional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                TextField("survey.content.placeholder", text: $store.content, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityLabel(Text("survey.content"))
            } header: { Text("survey.content") }
            Section {
                TextField("survey.situation.placeholder", text: $store.situation, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityLabel(Text("survey.situation"))
            } header: { Text("survey.situation") }
            Section {
                TextField("survey.suggestions.placeholder", text: $store.suggestions, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityLabel(Text("survey.suggestions"))
            } header: { Text("survey.suggestions") }
            Section {
                if store.isTooLong {
                    Text("survey.tooLong").foregroundStyle(.red)
                }
                Button { send(.submit) } label: {
                    HStack {
                        Text("survey.submit")
                        if store.isSubmitting { ProgressView() }
                    }
                }
                .disabled(!store.canSubmit)
            } footer: { Text("survey.privacy") }
        }
        .disabled(store.isSubmitting)
        .navigationTitle(Text("survey.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("survey.close") { dismiss() }
                    .disabled(store.isSubmitting)
            }
        }
        .interactiveDismissDisabled(store.isSubmitting)
        .alert("survey.thanks", isPresented: $store.submitted) {
            Button("OK") { dismiss() }
        } message: { Text("survey.thanks.message") }
        .alert("survey.error", isPresented: $store.failed) {
            Button("OK", role: .cancel) { }
        } message: { Text("survey.error.message") }
    }
}

#Preview {
    NavigationStack { UsageSurveyView() }
}
