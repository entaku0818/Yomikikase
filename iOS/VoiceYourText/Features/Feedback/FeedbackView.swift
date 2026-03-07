import SwiftUI
import Dependencies

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    @State private var isSubmitting: Bool = false
    @State private var submitted: Bool = false
    @Dependency(\.feedbackClient) var feedbackClient

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ご不便をおかけして申し訳ありません。\n改善のため、詳しく教えていただけますか？")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $message)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        Group {
                            if message.isEmpty {
                                Text("不満な点や改善してほしいことを入力してください")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .padding(14)
                                    .allowsHitTesting(false)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                    )

                Spacer()

                Button(action: submit) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("送信する")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(message.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(message.isEmpty || isSubmitting)
            }
            .padding()
            .navigationTitle("フィードバック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("送信完了", isPresented: $submitted) {
                Button("OK") { dismiss() }
            } message: {
                Text("フィードバックをありがとうございます。今後の改善に役立てます。")
            }
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await feedbackClient.submit(message)
                await MainActor.run {
                    isSubmitting = false
                    submitted = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                }
            }
        }
    }
}
