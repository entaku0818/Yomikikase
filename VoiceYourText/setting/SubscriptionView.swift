import SwiftUI
import RevenueCat
import SafariServices

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var isLoading = true
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showSafari = false
    @State private var safariURL: URL?
    
    // プライバシーポリシーと利用規約のURL
    private let privacyPolicyURL = URL(string: "https://voiceyourtext.web.app/privacy_policy.html")!
    private let termsOfServiceURL = URL(string: "https://voiceyourtext.web.app/terms_of_service.html")!
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("Premium Features")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Features list
                featuresSection
                
                // Subscription options
                subscriptionOptionsSection
                
                // プライバシーポリシーと利用規約リンク
                legalLinksSection
                
                // Restore purchases button
                Button(action: {
                    Task {
                        await restorePurchases()
                    }
                }) {
                    Text("Restore Purchases")
                        .foregroundColor(.blue)
                }
                .padding(.top)
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Premium")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchSubscriptionPlan()
                isLoading = false
            }
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unlock Premium Features")
                .font(.headline)
                .padding(.bottom, 4)
            
            FeatureRow(icon: "xmark.circle.fill", title: "広告の削除", description: "アプリ内の広告をすべて削除します")
            FeatureRow(icon: "doc.fill", title: "PDFファイルの登録", description: "PDFファイルを登録して音声読み上げに利用できます")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 16) {
            if isLoading {
                // 読み込み中はローディング状態のカードを表示
                SubscriptionOptionCard(
                    title: "",  // ローディング中は空文字
                    price: "",  // ローディング中は空文字
                    period: "Monthly",
                    isPopular: true,
                    action: {
                        // 読み込み中は何もしない
                    },
                    isLoading: true
                )
            } else {
                // 情報取得成功時
                if let monthlyPlan = viewModel.monthlyPlan {
                    SubscriptionOptionCard(
                        title: monthlyPlan.name,
                        price: monthlyPlan.price,
                        period: "Monthly",
                        isPopular: true,
                        action: {
                            Task {
                                await purchaseMonthly()
                            }
                        },
                        isLoading: viewModel.isProcessing
                    )
                } else {
                    // 情報取得失敗時もローディング状態のカードを表示
                    SubscriptionOptionCard(
                        title: "",
                        price: "",
                        period: "Monthly",
                        isPopular: true,
                        action: {
                            Task {
                                await purchaseMonthly()
                            }
                        },
                        isLoading: true
                    )
                }
            }
        }
    }
    
    // 利用規約とプライバシーポリシーへのリンクセクション
    private var legalLinksSection: some View {
        HStack(spacing: 20) {
            Button(action: {
                safariURL = privacyPolicyURL
                showSafari = true
            }) {
                Text("プライバシーポリシー")
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .underline()
            }
            
            Button(action: {
                safariURL = termsOfServiceURL
                showSafari = true
            }) {
                Text("利用規約")
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .underline()
            }
        }
        .padding(.top, 8)
    }
    
    private func purchaseMonthly() async {
        viewModel.isProcessing = true
        defer { viewModel.isProcessing = false }
        
        do {
            let success = try await PurchaseManager.shared.purchasePro()
            if success {
                alertTitle = "購入完了"
                alertMessage = "ご購入ありがとうございます！プレミアム機能がご利用いただけるようになりました。"
                showingAlert = true
            }
        } catch {
            handlePurchaseError(error)
        }
    }
    
    private func restorePurchases() async {
        viewModel.isProcessing = true
        defer { viewModel.isProcessing = false }
        
        do {
            let success = try await PurchaseManager.shared.restorePurchases()
            if success {
                alertTitle = "復元完了"
                alertMessage = "購入履歴の復元が完了しました。"
                showingAlert = true
            }
        } catch {
            alertTitle = "復元失敗"
            alertMessage = "購入履歴を復元できませんでした。後ほど再度お試しください。"
            showingAlert = true
        }
    }
    
    private func handlePurchaseError(_ error: Error) {
        if let purchaseError = error as? PurchaseManager.PurchaseError {
            switch purchaseError {
            case .productNotFound:
                alertTitle = "商品が見つかりません"
                alertMessage = "サブスクリプション商品が見つかりませんでした。後ほど再度お試しください。"
            case .purchaseFailed:
                alertTitle = "購入失敗"
                alertMessage = "購入処理を完了できませんでした。後ほど再度お試しください。"
            case .noEntitlements:
                alertTitle = "購入履歴なし"
                alertMessage = "復元できる購入履歴が見つかりませんでした。"
            }
        } else {
            alertTitle = "エラー"
            alertMessage = "予期せぬエラーが発生しました: \(error.localizedDescription)"
        }
        showingAlert = true
    }
}

// SafariView for displaying web content
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SubscriptionOptionCard: View {
    let title: String
    let price: String
    let period: String
    let isPopular: Bool
    let action: () -> Void
    var isLoading: Bool = false
    
    var body: some View {
        VStack {
            if isPopular {
                Text("PREMIUM")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.bottom, 4)
            }
            
            VStack(spacing: 12) {
                if isLoading {
                    // ローディング中はプレースホルダーを表示
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 20)
                        .cornerRadius(4)
                        .padding(.horizontal, 30)
                        
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 30)
                        .cornerRadius(4)
                        .padding(.horizontal, 60)
                } else {
                    Text(title)
                        .font(.headline)
                    
                    Text(price)
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                Text(period)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: action) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    } else {
                        Text("購入する")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .disabled(isLoading)
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPopular ? Color.blue : Color.clear, lineWidth: 2)
            )
            .opacity(isLoading ? 0.7 : 1)
        }
    }
}

class SubscriptionViewModel: ObservableObject {
    @Published var monthlyPlan: (name: String, price: String)?
    @Published var isProcessing: Bool = false
    
    func fetchSubscriptionPlan() async {
        do {
            let monthlyPlan = try await PurchaseManager.shared.fetchProPlan()
            
            await MainActor.run {
                self.monthlyPlan = monthlyPlan
            }
        } catch {
            print("Failed to fetch subscription plan: \(error)")
            // エラー時にはnilのままになるが、UIではデフォルト値を表示する
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
} 