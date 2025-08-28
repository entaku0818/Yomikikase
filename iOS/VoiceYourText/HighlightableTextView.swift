//
//  HighlightableTextView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/07/05.
//

import SwiftUI
import UIKit

struct HighlightableTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var highlightedRange: NSRange?
    let isEditable: Bool
    let fontSize: CGFloat
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: fontSize)
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.backgroundColor = UIColor.systemBackground
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // テキストが変更された場合のみ更新
        if uiView.text != text {
            uiView.text = text
        }
        
        // ハイライトを適用
        applyHighlight(to: uiView)
    }
    
    private func applyHighlight(to textView: UITextView) {
        let attributedString = NSMutableAttributedString(string: text)
        
        // デフォルトの属性を設定
        let fullRange = NSRange(location: 0, length: text.count)
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: fontSize), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        // ハイライトを適用
        if let range = highlightedRange,
           range.location != NSNotFound,
           range.location + range.length <= text.count {
            attributedString.addAttribute(.backgroundColor, value: UIColor.systemYellow, range: range)
            
            // ハイライト部分にスクロール
            DispatchQueue.main.async {
                if let textRange = textView.textRange(from: textView.beginningOfDocument, offset: range.location, length: range.length) {
                    textView.scrollRangeToVisible(range)
                }
            }
        }
        
        textView.attributedText = attributedString
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightableTextView
        
        init(_ parent: HighlightableTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            // テキストが変更されたらハイライトをクリア
            parent.highlightedRange = nil
        }
    }
}

// UITextView拡張：範囲からUITextRangeを作成
extension UITextView {
    func textRange(from position: UITextPosition, offset: Int, length: Int) -> UITextRange? {
        guard let start = self.position(from: position, offset: offset),
              let end = self.position(from: start, offset: length) else {
            return nil
        }
        return self.textRange(from: start, to: end)
    }
}

// プレビュー用のテストView
struct HighlightableTextViewPreview: View {
    @State private var text = "これはハイライト機能のテストテキストです。音声合成中に単語がハイライトされます。"
    @State private var highlightedRange: NSRange? = nil
    @State private var currentIndex = 0
    
    var body: some View {
        VStack {
            HighlightableTextView(
                text: $text,
                highlightedRange: $highlightedRange,
                isEditable: true,
                fontSize: 18
            )
            .frame(height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .padding()
            
            HStack {
                Button("ハイライトテスト") {
                    simulateHighlight()
                }
                
                Button("クリア") {
                    highlightedRange = nil
                    currentIndex = 0
                }
            }
            .padding()
        }
    }
    
    private func simulateHighlight() {
        let words = text.components(separatedBy: .whitespaces)
        guard currentIndex < words.count else {
            currentIndex = 0
            return
        }
        
        var location = 0
        for i in 0..<currentIndex {
            location += words[i].count + 1
        }
        
        highlightedRange = NSRange(location: location, length: words[currentIndex].count)
        currentIndex += 1
    }
}

#Preview {
    HighlightableTextViewPreview()
}