import SwiftUI
import RevenueCat
import SafariServices
import Dependencies

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
            FeatureRow(icon: "doc.fill", title: "PDFファイルの登録", description: "PDFファイルを3つ以上登録できるようになります")
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
                    title: viewModel.monthlyPlan?.name ?? "",  // ローディング中は空文字
                    price: viewModel.monthlyPlan?.price ?? "",  // ローディング中は空文字
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
                viewModel.trackPrivacyPolicyTap()
                safariURL = privacyPolicyURL
                showSafari = true
            }) {
                Text("プライバシーポリシー")
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .underline()
            }
            
            Button(action: {
                viewModel.trackTermsOfServiceTap()
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
        let result = await viewModel.handlePurchase()
        alertTitle = result.title
        alertMessage = result.message
        showingAlert = true
    }
    
    private func restorePurchases() async {
        let result = await viewModel.handleRestore()
        alertTitle = result.title
        alertMessage = result.message
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
    @Dependency(\.analytics) private var analytics
    
    func fetchSubscriptionPlan() async {
        do {
            let monthlyPlan = try await PurchaseManager.shared.fetchProPlan()
            
            await MainActor.run {
                self.monthlyPlan = monthlyPlan
            }
        } catch {
            print("Failed to fetch subscription plan: \(error)")
            analytics.logEvent("subscription_plan_fetch_failed", [
                "error": error.localizedDescription
            ])
        }
    }
    
    func handlePurchase() async -> (success: Bool, title: String, message: String) {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let success = try await PurchaseManager.shared.purchasePro()
            if success {
                analytics.logEvent("subscription_purchase_success", [
                    "plan_type": "monthly",
                    "source": "subscription_view"
                ])
                return (true, "購入完了", "ご購入ありがとうございます！プレミアム機能がご利用いただけるようになりました。")
            } else {
                analytics.logEvent("subscription_purchase_cancelled", nil)
                return (false, "購入キャンセル", "購入がキャンセルされました。")
            }
        } catch {
            analytics.logEvent("subscription_purchase_failed", [
                "plan_type": "monthly",
                "error": error.localizedDescription
            ])
            return handlePurchaseError(error)
        }
    }
    
    func handleRestore() async -> (success: Bool, title: String, message: String) {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let success = try await PurchaseManager.shared.restorePurchases()
            if success {
                analytics.logEvent("subscription_restore_success", nil)
                return (true, "復元完了", "購入履歴の復元が完了しました。")
            } else {
                analytics.logEvent("subscription_restore_failed", [
                    "reason": "no_purchases_found"
                ])
                return (false, "復元失敗", "復元可能な購入履歴が見つかりませんでした。")
            }
        } catch {
            analytics.logEvent("subscription_restore_failed", [
                "error": error.localizedDescription
            ])
            return (false, "復元失敗", "購入履歴を復元できませんでした。後ほど再度お試しください。")
        }
    }
    
    func trackPrivacyPolicyTap() {
        analytics.logEvent("privacy_policy_tap", [
            "source": "subscription_view"
        ])
    }
    
    func trackTermsOfServiceTap() {
        analytics.logEvent("terms_of_service_tap", [
            "source": "subscription_view"
        ])
    }
    
    private func handlePurchaseError(_ error: Error) -> (success: Bool, title: String, message: String) {
        if let purchaseError = error as? PurchaseManager.PurchaseError {
            switch purchaseError {
            case .productNotFound:
                return (false, "商品が見つかりません", "サブスクリプション商品が見つかりませんでした。後ほど再度お試しください。")
            case .purchaseFailed:
                return (false, "購入失敗", "購入処理を完了できませんでした。後ほど再度お試しください。")
            case .noEntitlements:
                return (false, "購入履歴なし", "復元できる購入履歴が見つかりませんでした。")
            }
        }
        return (false, "エラー", "予期せぬエラーが発生しました: \(error.localizedDescription)")
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
} 
