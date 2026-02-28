//
//  HighlightedTextEditor.swift
//  VoiceYourText
//
//  Created by Claude on 2025/07/05.
//

import SwiftUI
import Foundation

struct HighlightedTextEditor: View {
    @Binding var text: String
    @Binding var highlightedRange: NSRange?
    let height: CGFloat
    
    var body: some View {
        TextEditor(text: $text)
            .frame(height: height)
            .background(
                // ハイライト表示のオーバーレイ
                highlightOverlay
            )
    }
    
    private var highlightOverlay: some View {
        Group {
            if let highlightedRange = highlightedRange,
               highlightedRange.location != NSNotFound,
               highlightedRange.location + highlightedRange.length <= text.count {
                Rectangle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 100, height: 20) // 簡易的なハイライト表示
            }
        }
    }
    
}

// iOS 16.4+ でより良いサポート
@available(iOS 16.0, *)
struct AdvancedHighlightedTextEditor: View {
    @Binding var text: String
    @Binding var highlightedRange: NSRange?
    let height: CGFloat
    
    var body: some View {
        TextEditor(text: $text)
            .frame(height: height)
            .background(
                // ハイライト表示のオーバーレイ
                highlightOverlay
            )
            .onChange(of: text) { _ in
                // テキストが変更された場合、ハイライトをクリア
                highlightedRange = nil
            }
    }
    
    private var highlightOverlay: some View {
        Group {
            if let highlightedRange = highlightedRange,
               highlightedRange.location != NSNotFound,
               highlightedRange.location + highlightedRange.length <= text.count {
                Rectangle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 100, height: 20) // 簡易的なハイライト表示
            }
        }
    }
}

#Preview {
    @State var text = "This is a sample text for highlighting demonstration."
    @State var highlightedRange: NSRange? = NSRange(location: 10, length: 6)
    
    return VStack {
        HighlightedTextEditor(
            text: $text,
            highlightedRange: $highlightedRange,
            height: 100
        )
        .padding()
        
        Button("Toggle Highlight") {
            highlightedRange = highlightedRange == nil ? NSRange(location: 10, length: 6) : nil
        }
        .padding()
    }
}