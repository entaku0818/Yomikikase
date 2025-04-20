import Foundation

enum Config {
    // RevenueCat API Keys
    #if DEBUG
    // サンドボックス環境（開発時）のAPIキー
    // RevenueCatダッシュボード（https://app.revenuecat.com/）の
    // Project Settings > API Keys からSandbox用のAPIキーを取得してください
    static let revenueCatAPIKey = "appl_YOUR_ACTUAL_SANDBOX_API_KEY"
    #else
    // 本番環境のAPIキー
    // RevenueCatダッシュボード（https://app.revenuecat.com/）の
    // Project Settings > API Keys から本番用のAPIキーを取得してください
    static let revenueCatAPIKey = "appl_YOUR_ACTUAL_PRODUCTION_API_KEY"
    #endif
    
} 
