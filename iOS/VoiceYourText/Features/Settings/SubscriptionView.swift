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
    @State private var shouldDismissAfterAlert = false
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
                dismissButton: .default(Text("OK")) {
                    if shouldDismissAfterAlert {
                        dismiss()
                    }
                }
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
            FeatureRow(icon: "doc.fill", title: "無制限ファイル登録", description: "PDF・テキストファイルを無制限に登録できます（無料版は\(FileLimitsManager.maxFreeFileCount)個まで）")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 12) {
            // 年額プラン（おすすめ・上位表示）
            AnnualPlanCard(
                monthlyPlan: viewModel.monthlyPlan,
                annualPlan: viewModel.annualPlan,
                isLoading: isLoading,
                isProcessing: viewModel.isProcessing,
                onPurchase: {
                    Task { await purchaseAnnual() }
                }
            )

            // 月額プラン（セカンダリ）
            MonthlyPlanCard(
                plan: viewModel.monthlyPlan,
                isLoading: isLoading,
                isProcessing: viewModel.isProcessing,
                onPurchase: {
                    Task { await purchaseMonthly() }
                }
            )
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
        let result = await viewModel.handlePurchase(planType: .monthly)
        alertTitle = result.title
        alertMessage = result.message
        shouldDismissAfterAlert = result.success
        showingAlert = true
    }

    private func purchaseAnnual() async {
        let result = await viewModel.handlePurchase(planType: .annual)
        alertTitle = result.title
        alertMessage = result.message
        shouldDismissAfterAlert = result.success
        showingAlert = true
    }

    private func restorePurchases() async {
        let result = await viewModel.handleRestore()
        alertTitle = result.title
        alertMessage = result.message
        shouldDismissAfterAlert = result.success
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

// MARK: - 年額プランカード（おすすめ・メイン表示）
struct AnnualPlanCard: View {
    let monthlyPlan: (name: String, price: String)?
    let annualPlan: (name: String, price: String)?
    let isLoading: Bool
    let isProcessing: Bool
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // おすすめバッジ
            HStack {
                Spacer()
                Text("おすすめ・約38%お得")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(AppTheme.badgeBackground)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.bottom, 10)

            VStack(spacing: 10) {
                if isLoading {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 20)
                        .cornerRadius(4)
                        .padding(.horizontal, 30)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 36)
                        .cornerRadius(4)
                        .padding(.horizontal, 50)
                } else {
                    Text(annualPlan?.name ?? "年額プラン")
                        .font(.headline)
                    VStack(spacing: 2) {
                        if let price = annualPlan?.price {
                            Text(price)
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        if let monthly = monthlyPlan?.price {
                            Text("月額換算 \(monthly)/月 より割安")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Button(action: onPurchase) {
                    Group {
                        if isLoading || isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("年額プランで購入する")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(AppTheme.primary)
                    .cornerRadius(12)
                }
                .disabled(isLoading || isProcessing)
                .padding(.top, 4)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.annualCardBorder, lineWidth: 1.5)
            )
            .opacity(isLoading ? 0.7 : 1)
        }
    }
}

// MARK: - 月額プランカード（セカンダリ表示）
struct MonthlyPlanCard: View {
    let plan: (name: String, price: String)?
    let isLoading: Bool
    let isProcessing: Bool
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 18)
                    .cornerRadius(4)
                    .padding(.horizontal, 40)
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 28)
                    .cornerRadius(4)
                    .padding(.horizontal, 70)
            } else {
                Text(plan?.name ?? "月額プラン")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let price = plan?.price {
                    Text(price)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }

            Button(action: onPurchase) {
                Group {
                    if isLoading || isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("月額プランで購入する")
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.secondaryForeground)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.monthlyCardBorder, lineWidth: 1)
                )
            }
            .disabled(isLoading || isProcessing)
        }
        .padding()
        .opacity(isLoading ? 0.7 : 1)
    }
}

// 後方互換（既存コードが参照している場合のスタブ）
struct SubscriptionOptionCard: View {
    let title: String
    let price: String
    let isPopular: Bool
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View { EmptyView() }
}

class SubscriptionViewModel: ObservableObject {
    @Published var monthlyPlan: (name: String, price: String)?
    @Published var annualPlan: (name: String, price: String)?
    @Published var isProcessing: Bool = false
    @Dependency(\.analytics) private var analytics

    func fetchSubscriptionPlan() async {
        do {
            let plans = try await PurchaseManager.shared.fetchAllPlans()
            await MainActor.run {
                self.monthlyPlan = plans.monthly
                self.annualPlan = plans.annual
            }
        } catch {
            // フォールバック: 月額のみ取得
            do {
                let monthlyPlan = try await PurchaseManager.shared.fetchProPlan()
                await MainActor.run {
                    self.monthlyPlan = monthlyPlan
                }
            } catch {
                errorLog("Failed to fetch subscription plan: \(error)")
                analytics.logEvent("subscription_plan_fetch_failed", [
                    "error": error.localizedDescription
                ])
            }
        }
    }

    func handlePurchase(planType: PurchaseManager.PlanType = .monthly) async -> (success: Bool, title: String, message: String) {
        isProcessing = true
        defer { isProcessing = false }

        let planTypeString = planType == .annual ? "annual" : "monthly"

        do {
            let success = try await PurchaseManager.shared.purchasePro(planType: planType)
            if success {
                analytics.logEvent("subscription_purchase_success", [
                    "plan_type": planTypeString,
                    "source": "subscription_view"
                ])
                return (true, "購入完了", "ご購入ありがとうございます！プレミアム機能がご利用いただけるようになりました。")
            } else {
                analytics.logEvent("subscription_purchase_cancelled", nil)
                return (false, "購入キャンセル", "購入がキャンセルされました。")
            }
        } catch {
            analytics.logEvent("subscription_purchase_failed", [
                "plan_type": planTypeString,
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
