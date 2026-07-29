import Foundation
import FirebaseAppCheck
import FirebaseCore

/// Release向けApp Checkプロバイダ。
/// App Attestを優先し、生成できない場合はDeviceCheckにフォールバックする。
final class VoiceYourTextAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if let appAttest = AppAttestProvider(app: app) {
            return appAttest
        }
        return DeviceCheckProvider(app: app)
    }
}
