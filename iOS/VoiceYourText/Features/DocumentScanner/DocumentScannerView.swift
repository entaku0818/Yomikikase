//
//  DocumentScannerView.swift
//  VoiceYourText
//
//  Created by Claude on 2026/01/22.
//

import SwiftUI
import UIKit
import VisionKit
import Vision

struct DocumentScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onTextExtracted: (String, [String]) -> Void  // (text, imagePaths)
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // スキャンされた画像からテキストを抽出
            extractText(from: scan)
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onError(error.localizedDescription)
            controller.dismiss(animated: true)
        }

        private func extractText(from scan: VNDocumentCameraScan) {
            var extractedTexts: [String] = []
            var savedImagePaths: [String] = []
            let dispatchGroup = DispatchGroup()

            // スキャンIDを生成（すべてのページで同じIDを使用）
            let scanId = UUID().uuidString

            for pageIndex in 0..<scan.pageCount {
                dispatchGroup.enter()
                let image = scan.imageOfPage(at: pageIndex)

                // 画像を保存
                if let imagePath = saveImage(image, scanId: scanId, pageIndex: pageIndex) {
                    savedImagePaths.append(imagePath)
                }

                guard let cgImage = image.cgImage else {
                    dispatchGroup.leave()
                    continue
                }

                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNRecognizeTextRequest { request, error in
                    defer { dispatchGroup.leave() }

                    if let error = error {
                        print("Text recognition error: \(error.localizedDescription)")
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        return
                    }

                    let pageText = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }.joined(separator: "\n")

                    if !pageText.isEmpty {
                        extractedTexts.append(pageText)
                    }
                }

                // 日本語と英語の両方を認識
                request.recognitionLanguages = ["ja-JP", "en-US"]
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                do {
                    try requestHandler.perform([request])
                } catch {
                    print("Failed to perform text recognition: \(error.localizedDescription)")
                }
            }

            dispatchGroup.notify(queue: .main) {
                let fullText = extractedTexts.joined(separator: "\n\n")
                if fullText.isEmpty {
                    self.parent.onError("テキストを認識できませんでした")
                } else {
                    self.parent.onTextExtracted(fullText, savedImagePaths)
                }
            }
        }

        private func saveImage(_ image: UIImage, scanId: String, pageIndex: Int) -> String? {
            // 元のサイズのまま圧縮して保存（0.8 = 80%品質）
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                return nil
            }

            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let scansDirectory = documentsURL.appendingPathComponent("scans", isDirectory: true)

            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: scansDirectory.path) {
                try? fileManager.createDirectory(at: scansDirectory, withIntermediateDirectories: true)
            }

            // ファイル名: scanId_pageIndex.jpg
            let fileName = "\(scanId)_\(pageIndex).jpg"
            let fileURL = scansDirectory.appendingPathComponent(fileName)

            do {
                try imageData.write(to: fileURL)
                return fileName  // 相対パスのみを返す
            } catch {
                print("Failed to save image: \(error.localizedDescription)")
                return nil
            }
        }
    }
}

// スキャン機能が利用可能かチェック
extension DocumentScannerView {
    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }
}
