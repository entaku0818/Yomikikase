//
//  DebugLogView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/12/29.
//

import SwiftUI

struct DebugLogView: View {
    @StateObject private var logManager = DebugLogManager.shared
    @State private var showingShareSheet = false
    @State private var filterLevel: DebugLogManager.LogEntry.LogLevel? = nil

    var filteredLogs: [DebugLogManager.LogEntry] {
        if let level = filterLevel {
            return logManager.logs.filter { $0.level == level }
        }
        return logManager.logs
    }

    var body: some View {
        VStack(spacing: 0) {
            // フィルターボタン
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterButton(title: "全て", isSelected: filterLevel == nil) {
                        filterLevel = nil
                    }
                    FilterButton(title: "🔍 Debug", isSelected: filterLevel == .debug) {
                        filterLevel = .debug
                    }
                    FilterButton(title: "ℹ️ Info", isSelected: filterLevel == .info) {
                        filterLevel = .info
                    }
                    FilterButton(title: "⚠️ Warning", isSelected: filterLevel == .warning) {
                        filterLevel = .warning
                    }
                    FilterButton(title: "❌ Error", isSelected: filterLevel == .error) {
                        filterLevel = .error
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.systemGroupedBackground))

            Divider()

            // ログリスト
            if filteredLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("ログがありません")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("デバッグログ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Label("エクスポート", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive, action: {
                        logManager.clearLogs()
                    }) {
                        Label("クリア", systemImage: "trash")
                    }

                    Divider()

                    Button(action: {
                        // テストログを追加
                        debugLog("Test debug message")
                        infoLog("Test info message")
                        warningLog("Test warning message")
                        errorLog("Test error message")
                    }) {
                        Label("テストログ追加", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [logManager.exportLogs()])
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(UIColor.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct LogEntryRow: View {
    let entry: DebugLogManager.LogEntry

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.level.emoji)
                Text(dateFormatter.string(from: entry.timestamp))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(entry.file):\(entry.line)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Text(entry.message)
                .font(.system(size: 14))
                .foregroundColor(colorForLevel(entry.level))
        }
        .padding(.vertical, 4)
    }

    private func colorForLevel(_ level: DebugLogManager.LogEntry.LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DebugLogView()
    }
}
