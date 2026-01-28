//
//  DocumentScannerView.swift
//  VoiceYourText
//
//  Created by Claude on 2026/01/22.
//

import SwiftUI
import UIKit
import Vision

struct DocumentScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onTextExtracted: (String, [String]) -> Void  // (text, imagePaths)
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)

            guard let image = info[.originalImage] as? UIImage else {
                parent.onError("画像の読み込みに失敗しました")
                return
            }

            // 即座にOCR処理を開始
            extractText(from: image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        private func extractText(from image: UIImage) {
            // スキャンIDを生成
            let scanId = UUID().uuidString
            var savedImagePaths: [String] = []

            // 画像を保存
            if let imagePath = saveImage(image, scanId: scanId, pageIndex: 0) {
                savedImagePaths.append(imagePath)
            }

            guard let cgImage = image.cgImage else {
                parent.onError("画像の読み込みに失敗しました")
                return
            }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self else { return }

                if let error = error {
                    errorLog("Text recognition error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.parent.onError("テキスト認識に失敗しました")
                    }
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        self.parent.onError("テキストを認識できませんでした")
                    }
                    return
                }

                let extractedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                DispatchQueue.main.async {
                    infoLog("OCR completed. Extracted text length: \(extractedText.count)")
                    infoLog("Saved image paths count: \(savedImagePaths.count)")
                    infoLog("Saved image paths: \(savedImagePaths)")

                    if extractedText.isEmpty {
                        self.parent.onError("テキストを認識できませんでした")
                    } else {
                        infoLog("Calling onTextExtracted with \(savedImagePaths.count) image paths")
                        self.parent.onTextExtracted(extractedText, savedImagePaths)
                    }
                }
            }

            // 日本語と英語の両方を認識
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try requestHandler.perform([request])
                } catch {
                    errorLog("Failed to perform text recognition: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.parent.onError("テキスト認識に失敗しました")
                    }
                }
            }
        }

        private func saveImage(_ image: UIImage, scanId: String, pageIndex: Int) -> String? {
            // 元のサイズのまま圧縮して保存（0.8 = 80%品質）
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                print("Failed to convert image to JPEG data")
                return nil
            }

            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let scansDirectory = documentsURL.appendingPathComponent("scans", isDirectory: true)

            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: scansDirectory.path) {
                do {
                    try fileManager.createDirectory(at: scansDirectory, withIntermediateDirectories: true)
                    print("Created scans directory: \(scansDirectory.path)")
                } catch {
                    print("Failed to create scans directory: \(error.localizedDescription)")
                    return nil
                }
            }

            // ファイル名: scanId_pageIndex.jpg
            let fileName = "\(scanId)_\(pageIndex).jpg"
            let fileURL = scansDirectory.appendingPathComponent(fileName)

            do {
                try imageData.write(to: fileURL)
                print("Image saved successfully: \(fileURL.path) (\(imageData.count) bytes)")
                return fileName  // 相対パスのみを返す
            } catch {
                print("Failed to save image: \(error.localizedDescription)")
                return nil
            }
        }
    }
}

// カメラが利用可能かチェック
extension DocumentScannerView {
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
