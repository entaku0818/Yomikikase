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
    @State private var showingTextInput = false
    @State private var showingPDFPicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ヘッダーカード（グラデーション）
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("テキストや文書を読み上げる")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    showingTextInput = true
                                }) {
                                    Text("今すぐ試す")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.white)
                                        .cornerRadius(20)
                                }
                            }
                            Spacer()
                            
                            // スマートフォンアイコン
                            Image(systemName: "iphone")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(24)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.purple.opacity(0.8),
                                Color.blue.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // インポート&リスニング
                    VStack(alignment: .leading, spacing: 16) {
                        Text("インポート&リスニング")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            // テキストボタン
                            Button(action: {
                                showingTextInput = true
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue)
                                    Text("テキスト")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 80, height: 80)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // PDFボタン
                            Button(action: {
                                showingPDFPicker = true
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.richtext")
                                        .font(.system(size: 32))
                                        .foregroundColor(.red)
                                    Text("PDF")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 80, height: 80)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // 最近の読み上げ
                    VStack(alignment: .leading, spacing: 16) {
                        Text("最近の読み上げ")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        WithViewStore(store, observe: { $0 }) { viewStore in
                            LazyVStack(spacing: 8) {
                                ForEach(Array(viewStore.speechList.prefix(3))) { speech in
                                    RecentItemView(
                                        title: speech.title,
                                        subtitle: "テキスト",
                                        date: speech.updatedAt,
                                        progress: 0
                                    )
                                    .onTapGesture {
                                        // 読み上げ開始
                                        viewStore.send(.speechSelected(speech.text))
                                        showingTextInput = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Voice Narrator")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingTextInput) {
            TextInputView(store: store)
        }
        .sheet(isPresented: $showingPDFPicker) {
            PDFPickerView()
        }
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
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    HomeView(store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
        Speeches()
    })
}