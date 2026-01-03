//
//  HomeView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers
import Dependencies

struct HomeView: View {
    let store: Store<Speeches.State, Speeches.Action>
    let onDevelopmentFeature: (String) -> Void

    @State private var showingTextFilePicker = false
    @State private var importedText: String = ""
    @State private var showingImportedTextView = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var showingPremiumAlert = false
    @State private var showingSubscription = false
    @State private var showingNewTextView = false

    @Dependency(\.textFileImport) var textFileImport

    var body: some View {
        NavigationStack {
            WithViewStore(store, observe: { $0 }) { viewStore in
                ScrollView {
                    VStack(spacing: 20) {
                        // 機能ボタングリッド
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            
                            // テキスト（有効）
                            Button {
                                if FileLimitsManager.hasReachedFreeLimit() {
                                    showingPremiumAlert = true
                                } else {
                                    showingNewTextView = true
                                }
                            } label: {
                                createButtonContent(
                                    icon: "doc.text.fill",
                                    iconColor: .blue,
                                    title: "テキスト",
                                    isEnabled: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // PDF（有効）
                            NavigationLink(destination: SimplePDFPickerView()) {
                                createButtonContent(
                                    icon: "doc.richtext.fill",
                                    iconColor: .red,
                                    title: "PDF",
                                    isEnabled: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            // TXTファイル（有効）
                            Button {
                                if FileLimitsManager.hasReachedFreeLimit() {
                                    showingPremiumAlert = true
                                } else {
                                    showingTextFilePicker = true
                                }
                            } label: {
                                createButtonContent(
                                    icon: "doc.plaintext.fill",
                                    iconColor: .purple,
                                    title: "TXTファイル",
                                    isEnabled: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Googleドライブ（無効）
                            createButtonCard(
                                icon: "externaldrive.fill",
                                iconColor: .green,
                                title: "Gドライブ",
                                isEnabled: false,
                                action: { onDevelopmentFeature("Googleドライブ") }
                            )
                            
                            // Kindle（無効）
                            createButtonCard(
                                icon: "book.fill",
                                iconColor: .orange,
                                title: "Kindle",
                                isEnabled: false,
                                action: { onDevelopmentFeature("Kindle") }
                            )
                            
                            // 本（無効）
                            createButtonCard(
                                icon: "books.vertical.fill",
                                iconColor: .brown,
                                title: "本",
                                isEnabled: false,
                                action: { onDevelopmentFeature("本") }
                            )
                            
                            // スキャン（無効）
                            createButtonCard(
                                icon: "camera.fill",
                                iconColor: .gray,
                                title: "スキャン",
                                isEnabled: false,
                                action: { onDevelopmentFeature("スキャン") }
                            )
                            
                            // リンク（無効）
                            createButtonCard(
                                icon: "link",
                                iconColor: .cyan,
                                title: "リンク",
                                isEnabled: false,
                                action: { onDevelopmentFeature("リンク") }
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // 最近のファイル
                        if !viewStore.speechList.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("最近のファイル")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(viewStore.speechList.prefix(3))) { speech in
                                        HStack {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.blue)
                                                .frame(width: 32, height: 32)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(6)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(speech.title)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .lineLimit(1)
                                                
                                                Text(speech.updatedAt, style: .date)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            NavigationLink(destination: TextInputView(store: store, initialText: speech.text, fileId: speech.id)) {
                                                Image(systemName: "play.circle")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.blue)
                                            }
                                            .simultaneousGesture(TapGesture().onEnded {
                                                viewStore.send(.speechSelected(speech.text))
                                            })
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // 広告バナー（最下部）
                if !UserDefaultsManager.shared.isPremiumUser {
                    AdmobBannerView()
                        .frame(height: 50)
                }
            }
            .navigationTitle("Voice Narrator")
            .navigationBarTitleDisplayMode(.large)
            .fileImporter(
                isPresented: $showingTextFilePicker,
                allowedContentTypes: [UTType.plainText, UTType.utf8PlainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            do {
                                importedText = try await textFileImport.readTextFile(url)
                                showingImportedTextView = true
                            } catch {
                                importErrorMessage = error.localizedDescription
                                showingImportError = true
                            }
                        }
                    }
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                    showingImportError = true
                }
            }
            .navigationDestination(isPresented: $showingImportedTextView) {
                TextInputView(store: store, initialText: importedText, fileId: nil)
            }
            .alert("エラー", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage)
            }
            .alert("プレミアム機能が必要です", isPresented: $showingPremiumAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("詳細を見る") {
                    showingSubscription = true
                }
            } message: {
                Text("無料版では最大\(FileLimitsManager.maxFreeFileCount)個までのファイル（PDF・テキスト合計）を登録できます。プレミアム版にアップグレードすると、無制限にファイルを登録できます。")
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            .fullScreenCover(isPresented: $showingNewTextView) {
                TextInputView(store: store, initialText: "", fileId: nil)
            }
        }
    }
    
    @ViewBuilder
    private func createButtonContent(
        icon: String,
        iconColor: Color,
        title: String,
        isEnabled: Bool
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(isEnabled ? iconColor : Color.gray.opacity(0.5))
                .frame(width: 50, height: 50)
                .background((isEnabled ? iconColor : Color.gray).opacity(0.1))
                .cornerRadius(12)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(isEnabled ? Color(.systemBackground) : Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(isEnabled ? 0.05 : 0.02), radius: isEnabled ? 4 : 2, x: 0, y: isEnabled ? 2 : 1)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    @ViewBuilder
    private func createButtonCard(
        icon: String,
        iconColor: Color,
        title: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isEnabled ? iconColor : Color.gray.opacity(0.5))
                    .frame(width: 50, height: 50)
                    .background((isEnabled ? iconColor : Color.gray).opacity(0.1))
                    .cornerRadius(12)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isEnabled ? Color(.systemBackground) : Color(.systemGray6))
            .cornerRadius(16)
            .shadow(color: .black.opacity(isEnabled ? 0.05 : 0.02), radius: isEnabled ? 4 : 2, x: 0, y: isEnabled ? 2 : 1)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentItemView: View {
    let title: String
    let subtitle: String
    let date: Date
    let progress: Int
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        HStack {
            // ファイルアイコン
            Image(systemName: subtitle == "PDF" ? "doc.richtext.fill" : "doc.text.fill")
                .font(.system(size: 24))
                .foregroundColor(subtitle == "PDF" ? .red : .blue)
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                HStack {
                    Text("\(progress)%")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(dateFormatter.string(from: date))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(subtitle.lowercased())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    HomeView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        onDevelopmentFeature: { _ in }
    )
}