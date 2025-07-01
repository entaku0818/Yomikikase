//
//  HomeView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: Store<Speeches.State, Speeches.Action>
    let onDevelopmentFeature: (String) -> Void
    
    var body: some View {
        NavigationStack {
            WithViewStore(store, observe: { $0 }) { viewStore in
                ScrollView {
                    VStack(spacing: 20) {
                        // 機能ボタングリッド
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            
                            // テキスト（有効）
                            NavigationLink(destination: TextInputView(store: store)) {
                                createButtonContent(
                                    icon: "doc.text.fill",
                                    iconColor: .blue,
                                    title: "テキスト",
                                    isEnabled: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // PDF（有効）
                            NavigationLink(destination: PDFPickerView()) {
                                createButtonContent(
                                    icon: "doc.richtext.fill",
                                    iconColor: .red,
                                    title: "PDF",
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
                                            
                                            NavigationLink(destination: TextInputView(store: store)) {
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
            }
            .navigationTitle("Voice Narrator")
            .navigationBarTitleDisplayMode(.large)
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