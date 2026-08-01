//
//  KokoroTTSClientTests.swift
//  VoiceYourTextTests
//
//  QA: KokoroTTSClient (TCA Dependency) のユニットテスト (Issue #54)
//  カバレッジ:
//   - KokoroTTSClient のデフォルト値 / スタブ注入した synthesize の正常系
//   - synthesize が投げる各 KokoroError（modelNotDownloaded / unavailable / synthesisFailure）
//   - KokoroError.errorDescription の文言（ローカライズ契約）
//   - DependencyValues 経由での差し替え（@Dependency(\.kokoroTTS)）
//
//  注意: KokoroTTSClient.liveValue は約600MBのモデルロード（KokoroEngine / MLX）を伴うため
//  ユニットテストでは呼ばず、@DependencyClient が生成するイニシャライザでスタブを構築して検証する。

import XCTest
import ComposableArchitecture
@testable import VoiceYourText

@MainActor
final class KokoroTTSClientTests: XCTestCase {

    // MARK: - synthesize 正常系（スタブ注入）

    /// 注入した synthesize がそのまま呼ばれ、引数が透過的に渡る
    func test_synthesize_returnsStubbedData() async throws {
        let expected = Data([0x52, 0x49, 0x46, 0x46]) // "RIFF"
        var capturedText: String?
        var capturedVoice: KokoroVoice?
        var capturedSpeed: Float?

        let client = KokoroTTSClient(
            isAvailable: { true },
            synthesize: { text, voice, speed in
                capturedText = text
                capturedVoice = voice
                capturedSpeed = speed
                return expected
            }
        )

        let data = try await client.synthesize(text: "こんにちは", voice: .jfAlpha, speed: 1.25)

        XCTAssertEqual(data, expected)
        XCTAssertEqual(capturedText, "こんにちは")
        XCTAssertEqual(capturedVoice, .jfAlpha)
        XCTAssertEqual(capturedSpeed, 1.25)
        XCTAssertTrue(client.isAvailable())
    }

    // MARK: - synthesize エラー系

    func test_synthesize_throwsModelNotDownloaded() async {
        let client = KokoroTTSClient(
            isAvailable: { false },
            synthesize: { _, _, _ in throw KokoroError.modelNotDownloaded }
        )

        await assertThrowsKokoroError(client) { error in
            guard case .modelNotDownloaded = error else {
                XCTFail("Expected .modelNotDownloaded, got \(error)")
                return
            }
        }
    }

    func test_synthesize_throwsUnavailable() async {
        let client = KokoroTTSClient(
            isAvailable: { false },
            synthesize: { _, _, _ in throw KokoroError.unavailable }
        )

        await assertThrowsKokoroError(client) { error in
            guard case .unavailable = error else {
                XCTFail("Expected .unavailable, got \(error)")
                return
            }
        }
    }

    func test_synthesize_throwsSynthesisFailure_withMessage() async {
        let client = KokoroTTSClient(
            isAvailable: { true },
            synthesize: { _, _, _ in throw KokoroError.synthesisFailure("model load failed") }
        )

        await assertThrowsKokoroError(client) { error in
            guard case let .synthesisFailure(message) = error else {
                XCTFail("Expected .synthesisFailure, got \(error)")
                return
            }
            XCTAssertEqual(message, "model load failed")
        }
    }

    // MARK: - KokoroError.errorDescription（文言契約）

    func test_errorDescription_modelNotDownloaded() {
        XCTAssertEqual(
            KokoroError.modelNotDownloaded.errorDescription,
            "Kokoroモデルがダウンロードされていません"
        )
    }

    func test_errorDescription_unavailable() {
        XCTAssertEqual(
            KokoroError.unavailable.errorDescription,
            "iOS 18以上が必要です"
        )
    }

    func test_errorDescription_packageNotInstalled() {
        XCTAssertEqual(
            KokoroError.packageNotInstalled.errorDescription,
            "KokoroSwiftパッケージが追加されていません"
        )
    }

    func test_errorDescription_synthesisFailure_embedsMessage() {
        XCTAssertEqual(
            KokoroError.synthesisFailure("boom").errorDescription,
            "音声合成失敗: boom"
        )
    }

    // MARK: - DependencyValues 経由の差し替え

    /// @Dependency(\.kokoroTTS) が withDependencies の上書きを解決する
    func test_dependency_override_isResolved() async throws {
        try await withDependencies {
            $0.kokoroTTS = KokoroTTSClient(
                isAvailable: { true },
                synthesize: { _, _, _ in Data([0xAB]) }
            )
        } operation: {
            @Dependency(\.kokoroTTS) var kokoroTTS
            XCTAssertTrue(kokoroTTS.isAvailable())
            let data = try await kokoroTTS.synthesize(text: "hi", voice: .afHeart, speed: 1.0)
            XCTAssertEqual(data, Data([0xAB]))
        }
    }

    // MARK: - Helpers

    private func assertThrowsKokoroError(
        _ client: KokoroTTSClient,
        _ assert: (KokoroError) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await client.synthesize(text: "t", voice: .afHeart, speed: 1.0)
            XCTFail("Expected KokoroError to be thrown", file: file, line: line)
        } catch let error as KokoroError {
            assert(error)
        } catch {
            XCTFail("Expected KokoroError, got \(error)", file: file, line: line)
        }
    }
}
