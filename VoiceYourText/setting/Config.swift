import Foundation

enum Config {
    // RevenueCat API Keys
    #if DEBUG
    static let revenueCatAPIKey = "appl_YOUR_SANDBOX_API_KEY" // Replace with your sandbox API key
    #else
    static let revenueCatAPIKey = "appl_YOUR_SANDBOX_API_KEY" // Replace with your production API key
    #endif
    
} 
