//
//  Kokoro-tts-lib
//
import Foundation

/// Supported languages for text-to-speech synthesis.
/// This enum defines the available language variants that can be used with the Kokoro TTS engine.
public enum Language: String, CaseIterable {
  case none  = ""
  case enUS  = "en-us"
  case enGB  = "en-gb"
  case ja    = "ja"
}
