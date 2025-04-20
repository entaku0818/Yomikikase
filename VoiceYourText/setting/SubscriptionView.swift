import SwiftUI
import RevenueCat

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var isLoading = true
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
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
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
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
                ProgressView()
                    .padding()
                
                // バックアップとして読み込み中でも購入ボタンを表示
                SubscriptionOptionCard(
                    title: "Premium Plan",
                    price: "¥480",
                    period: "Monthly",
                    isPopular: true,
                    action: {
                        Task {
                            await purchaseMonthly()
                        }
                    }
                )
                .opacity(0.5) // 読み込み中は半透明に
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
                        }
                    )
                } else {
                    // 情報取得失敗時もデフォルト値で表示
                    SubscriptionOptionCard(
                        title: "Premium Plan",
                        price: "¥480",
                        period: "Monthly",
                        isPopular: true,
                        action: {
                            Task {
                                await purchaseMonthly()
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func purchaseMonthly() async {
        isLoading = true
        defer { isLoading = false }
        
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
        isLoading = true
        defer { isLoading = false }
        
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
                Text(title)
                    .font(.headline)
                
                Text(price)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(period)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: action) {
                    Text("購入する")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPopular ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

class SubscriptionViewModel: ObservableObject {
    @Published var monthlyPlan: (name: String, price: String)?
    
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