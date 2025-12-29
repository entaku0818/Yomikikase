//
//  DebugLogManager.swift
//  VoiceYourText
//
//  Created by Claude on 2025/12/29.
//

import Foundation
import UIKit

class DebugLogManager: ObservableObject {
    static let shared = DebugLogManager()

    @Published var logs: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let file: String
        let function: String
        let line: Int

        enum LogLevel: String {
            case debug = "DEBUG"
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"

            var emoji: String {
                switch self {
                case .debug: return "🔍"
                case .info: return "ℹ️"
                case .warning: return "⚠️"
                case .error: return "❌"
                }
            }
        }
    }

    private let maxLogs = 500
    private let queue = DispatchQueue(label: "com.voiceyourtext.debuglog", qos: .utility)

    private init() {
        #if DEBUG
        // 起動時のシステム情報をログ
        logSystemInfo()
        #endif
    }

    func log(
        _ message: String,
        level: LogEntry.LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line
        )

        queue.async { [weak self] in
            DispatchQueue.main.async {
                self?.logs.insert(entry, at: 0)
                if let count = self?.logs.count, count > self!.maxLogs {
                    self?.logs.removeLast()
                }
            }
        }

        // コンソールにも出力
        print("[\(entry.level.rawValue)] \(entry.file):\(entry.line) - \(message)")
        #endif
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .debug, file: file, function: function, line: line)
        #endif
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .info, file: file, function: function, line: line)
        #endif
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .warning, file: file, function: function, line: line)
        #endif
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .error, file: file, function: function, line: line)
        #endif
    }

    func clearLogs() {
        #if DEBUG
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
        #endif
    }

    func exportLogs() -> String {
        #if DEBUG
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        return logs.reversed().map { entry in
            "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] \(entry.file):\(entry.line) \(entry.function) - \(entry.message)"
        }.joined(separator: "\n")
        #else
        return ""
        #endif
    }

    private func logSystemInfo() {
        #if DEBUG
        let device = UIDevice.current
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let iosVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        info("=== App Started ===")
        info("iOS Version: \(iosVersion)")
        info("Device: \(device.model)")
        info("System Name: \(device.systemName)")

        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info("App Version: \(appVersion) (\(buildNumber))")
        }
        #endif
    }
}

// グローバルなログ関数（DEBUGビルドのみ動作）
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    DebugLogManager.shared.debug(message, file: file, function: function, line: line)
    #endif
}

func infoLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    DebugLogManager.shared.info(message, file: file, function: function, line: line)
    #endif
}

func warningLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    DebugLogManager.shared.warning(message, file: file, function: function, line: line)
    #endif
}

func errorLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    DebugLogManager.shared.error(message, file: file, function: function, line: line)
    #endif
}
