//
//  DeletedItemsView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import ComposableArchitecture

struct DeletedItemsView: View {
    @Bindable var store: StoreOf<DeletedItemsFeature>

    var body: some View {
        VStack(spacing: 0) {
            if store.deletedFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("削除済みのファイルはありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("削除したファイルは7日間保持されます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.deletedFiles) { file in
                            DeletedFileItemView(
                                file: file,
                                onRestore: {
                                    store.send(.restoreTapped(file))
                                },
                                onDelete: {
                                    store.send(.deleteTapped(file))
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("削除済み項目")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            store.send(.onAppear)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

// MARK: - DeletedFileItemView

struct DeletedFileItemView: View {
    let file: DeletedFileItem
    var onRestore: (() -> Void)?
    var onDelete: (() -> Void)?

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 28))
                .foregroundColor(.gray)
                .frame(width: 48, height: 48)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(2)

                HStack {
                    Text("\(dateFormatter.string(from: file.deletedAt))に削除")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("あと\(file.daysRemaining)日")
                        .font(.system(size: 14))
                        .foregroundColor(file.daysRemaining <= 1 ? .red : .secondary)
                }
            }

            Spacer()

            Menu {
                if let onRestore = onRestore {
                    Button(action: onRestore) {
                        Label("復元", systemImage: "arrow.uturn.backward")
                    }
                }
                if let onDelete = onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("完全に削除", systemImage: "trash.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    NavigationStack {
        DeletedItemsView(
            store: Store(initialState: DeletedItemsFeature.State()) {
                DeletedItemsFeature()
            }
        )
    }
}
