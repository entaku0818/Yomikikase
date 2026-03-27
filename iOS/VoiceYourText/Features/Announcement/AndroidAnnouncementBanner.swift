import SwiftUI

/// Android版リリース告知バナー
/// UserDefaultsで閉じた状態を管理し、一度閉じたら再表示しない
struct AndroidAnnouncementBanner: View {
    @State private var isDismissed = UserDefaults.standard.bool(forKey: "androidBannerDismissed")

    var body: some View {
        if !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "android")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.green.opacity(0.8))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Android版が登場！")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Google Playで公開中。7言語・PDF対応。")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isDismissed = true
                        UserDefaults.standard.set(true, forKey: "androidBannerDismissed")
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.2, green: 0.6, blue: 0.3))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack {
        AndroidAnnouncementBanner()
        Spacer()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
